import AppKit
import SwiftUI

/// Native JSON syntax highlighter. Produces an `NSAttributedString` with
/// color attributes applied to keys, strings, numbers, booleans, and null.
enum JSONHighlighter {
    enum TokenType {
        case key, string, number, boolean, null
    }

    struct Token {
        let type: TokenType
        let range: NSRange
    }

    static func highlight(_ source: String, scheme: ColorScheme) -> NSAttributedString {
        let result = NSMutableAttributedString(string: source)
        let full = NSRange(location: 0, length: result.length)
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        result.addAttribute(.font, value: font, range: full)
        result.addAttribute(.foregroundColor, value: Palette.text(scheme), range: full)

        for token in tokenize(source) {
            result.addAttribute(.foregroundColor, value: Palette.color(for: token.type, scheme: scheme), range: token.range)
        }
        return result
    }

    static func tokenize(_ source: String) -> [Token] {
        let chars = Array(source.utf16)
        let n = chars.count
        var tokens: [Token] = []
        var i = 0

        while i < n {
            let c = chars[i]

            // whitespace
            if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D {
                i += 1
                continue
            }
            // structural punctuation — no token; default text color
            if c == 0x7B || c == 0x7D || c == 0x5B || c == 0x5D || c == 0x2C || c == 0x3A {
                i += 1
                continue
            }
            // string (may be a key if followed by `:`)
            if c == 0x22 {
                let start = i
                i += 1
                while i < n {
                    let ch = chars[i]
                    if ch == 0x5C {
                        i += min(2, n - i)
                        continue
                    }
                    i += 1
                    if ch == 0x22 { break }
                }
                var j = i
                while j < n {
                    let cj = chars[j]
                    if cj == 0x20 || cj == 0x09 || cj == 0x0A || cj == 0x0D {
                        j += 1
                    } else { break }
                }
                let isKey = j < n && chars[j] == 0x3A
                tokens.append(Token(type: isKey ? .key : .string, range: NSRange(location: start, length: i - start)))
                continue
            }
            // number
            if c == 0x2D || (c >= 0x30 && c <= 0x39) {
                let start = i
                if c == 0x2D { i += 1 }
                while i < n {
                    let ch = chars[i]
                    if (ch >= 0x30 && ch <= 0x39) || ch == 0x2E || ch == 0x65 || ch == 0x45 || ch == 0x2B || ch == 0x2D {
                        i += 1
                    } else { break }
                }
                tokens.append(Token(type: .number, range: NSRange(location: start, length: i - start)))
                continue
            }
            // true
            if c == 0x74 && i + 4 <= n && chars[i+1] == 0x72 && chars[i+2] == 0x75 && chars[i+3] == 0x65 {
                tokens.append(Token(type: .boolean, range: NSRange(location: i, length: 4)))
                i += 4
                continue
            }
            // false
            if c == 0x66 && i + 5 <= n && chars[i+1] == 0x61 && chars[i+2] == 0x6C && chars[i+3] == 0x73 && chars[i+4] == 0x65 {
                tokens.append(Token(type: .boolean, range: NSRange(location: i, length: 5)))
                i += 5
                continue
            }
            // null
            if c == 0x6E && i + 4 <= n && chars[i+1] == 0x75 && chars[i+2] == 0x6C && chars[i+3] == 0x6C {
                tokens.append(Token(type: .null, range: NSRange(location: i, length: 4)))
                i += 4
                continue
            }
            // unrecognized — skip
            i += 1
        }
        return tokens
    }
}

private enum Palette {
    static func text(_ scheme: ColorScheme) -> NSColor {
        scheme == .dark ? NSColor(white: 0.88, alpha: 1.0) : NSColor(white: 0.12, alpha: 1.0)
    }

    static func color(for type: JSONHighlighter.TokenType, scheme: ColorScheme) -> NSColor {
        switch scheme {
        case .dark:
            switch type {
            case .key:     return NSColor(red: 0.94, green: 0.42, blue: 0.34, alpha: 1.0)
            case .string:  return NSColor(red: 0.61, green: 0.86, blue: 0.55, alpha: 1.0)
            case .number:  return NSColor(red: 0.85, green: 0.65, blue: 0.32, alpha: 1.0)
            case .boolean: return NSColor(red: 0.76, green: 0.51, blue: 0.92, alpha: 1.0)
            case .null:    return NSColor(red: 0.58, green: 0.58, blue: 0.58, alpha: 1.0)
            }
        default:
            switch type {
            case .key:     return NSColor(red: 0.72, green: 0.20, blue: 0.16, alpha: 1.0)
            case .string:  return NSColor(red: 0.20, green: 0.50, blue: 0.21, alpha: 1.0)
            case .number:  return NSColor(red: 0.69, green: 0.40, blue: 0.08, alpha: 1.0)
            case .boolean: return NSColor(red: 0.43, green: 0.13, blue: 0.65, alpha: 1.0)
            case .null:    return NSColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0)
            }
        }
    }
}
