import CoreServices
import Foundation

/// Watches a workspace directory recursively via FSEvents and fires a callback
/// on any change (file create/modify/delete, folder rename, etc.).
final class WorkspaceWatcher {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, contextInfo, _, _, _, _ in
            guard let contextInfo else { return }
            let watcher = Unmanaged<WorkspaceWatcher>.fromOpaque(contextInfo).takeUnretainedValue()
            MainActor.assumeIsolated {
                watcher.onChange()
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
