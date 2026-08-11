import SwiftUI

enum OvertureTheme {
    static let ink = Color(red: 0.024, green: 0.035, blue: 0.051)
    static let cobalt = Color(red: 0.173, green: 0.408, blue: 1)
    static let muted = Color(red: 0.66, green: 0.69, blue: 0.74)
    static let divider = Color.white.opacity(0.14)

    static func editorial(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
