import Foundation

/// On-disk representation of a saved request (`*.chopper.json`).
struct RequestFile: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let fileExtension = "chopper.json"

    var schemaVersion: Int
    var method: HTTPMethod
    var url: String
    var headers: [Pair]
    var queryParams: [Pair]
    var body: Body

    struct Pair: Codable, Equatable {
        var name: String
        var value: String
        var enabled: Bool
    }

    struct Body: Codable, Equatable {
        var type: HTTPBodyType
        var content: String
    }
}

extension RequestFile {
    init(from request: HTTPRequest) {
        self.init(
            schemaVersion: Self.currentSchemaVersion,
            method: request.method,
            url: request.url,
            headers: request.headers.map(Pair.init),
            queryParams: request.queryParams.map(Pair.init),
            body: Body(type: request.body.type, content: request.body.content)
        )
    }

    func toHTTPRequest() -> HTTPRequest {
        HTTPRequest(
            method: method,
            url: url,
            headers: headers.map { $0.toKeyValuePair() },
            queryParams: queryParams.map { $0.toKeyValuePair() },
            body: HTTPBody(type: body.type, content: body.content)
        )
    }
}

private extension RequestFile.Pair {
    nonisolated init(_ kv: KeyValuePair) {
        self.init(name: kv.name, value: kv.value, enabled: kv.isEnabled)
    }

    nonisolated func toKeyValuePair() -> KeyValuePair {
        KeyValuePair(name: name, value: value, isEnabled: enabled)
    }
}

enum RequestFileError: LocalizedError {
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let v):
            return "Unsupported request file schema version: \(v). This file was created by a newer version of Chopper."
        }
    }
}

enum RequestStore {
    static func read(from url: URL) throws -> HTTPRequest {
        let data = try Data(contentsOf: url)
        let migrated = try migrate(data)
        let file = try decoder.decode(RequestFile.self, from: migrated)
        return file.toHTTPRequest()
    }

    static func write(_ request: HTTPRequest, to url: URL) throws {
        let file = RequestFile(from: request)
        let data = try encoder.encode(file)
        try data.write(to: url, options: [.atomic])
    }

    /// Steps a file's JSON up to `currentSchemaVersion` one hop at a time.
    /// Add a new `if version < N` block each time the on-disk format changes.
    private static func migrate(_ data: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        let version = json["schemaVersion"] as? Int ?? 1

        if version > RequestFile.currentSchemaVersion {
            throw RequestFileError.unsupportedSchemaVersion(version)
        }

        // for the next bump we do something like this
        // if version < 2 {
        //     json["query"] = json.removeValue(forKey: "queryParams") ?? []
        //     version = 2
        // }

        json["schemaVersion"] = RequestFile.currentSchemaVersion
        return try JSONSerialization.data(withJSONObject: json)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    private static let decoder = JSONDecoder()
}
