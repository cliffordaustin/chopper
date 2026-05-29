import SwiftUI
import AppKit

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
    }
}

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let button: CGFloat = 6
        static let card: CGFloat = 8
        static let sheet: CGFloat = 10
    }

    enum FontSize {
        static let title: CGFloat = 17
        static let section: CGFloat = 13
        static let body: CGFloat = 13
        static let mono: CGFloat = 12
        static let caption: CGFloat = 11
    }

    enum Colors {
        static var windowBackground: Color {
            Color(nsColor: NSColor(name: "windowBackground") { appearance in
                appearance.isDarkMode
                    ? NSColor(srgbRed: 31/255, green: 31/255, blue: 30/255, alpha: 1)
                    : NSColor(srgbRed: 247/255, green: 247/255, blue: 245/255, alpha: 1)
            })
        }

        static var sidebarBackground: Color {
            Color(nsColor: NSColor(name: "sidebarBackground") { appearance in
                appearance.isDarkMode
                    ? NSColor(srgbRed: 38/255, green: 38/255, blue: 38/255, alpha: 1)
                    : NSColor(srgbRed: 252/255, green: 252/255, blue: 250/255, alpha: 1)
            })
        }

        static var sidebarBorder: Color {
            Color(nsColor: NSColor(name: "sidebarBorder") { appearance in
                appearance.isDarkMode
                    ? NSColor(white: 1.0, alpha: 0.08)
                    : NSColor(white: 0.0, alpha: 0.10)
            })
        }

        static var separator: Color { Color(nsColor: .separatorColor) }
        static var paneBackground: Color { windowBackground }
        static var cardBackground: Color { Color(nsColor: .controlBackgroundColor) }
        static var subtleHover: Color { Color.primary.opacity(0.06) }
        static var subtleSelection: Color { Color.primary.opacity(0.12) }
    }

    static func color(for method: HTTPMethod) -> Color {
        switch method {
        case .get: return .green
        case .post: return .orange
        case .put, .patch: return .blue
        case .delete: return .red
        }
    }
}

struct MethodBadge: View {
    let method: HTTPMethod
    var compact: Bool = false

    var body: some View {
        Text(method.rawValue)
            .font(.system(size: compact ? 9 : 10, design: .monospaced).weight(.bold))
            .foregroundStyle(Theme.color(for: method))
            .frame(minWidth: compact ? 28 : 36, alignment: .leading)
    }
}
