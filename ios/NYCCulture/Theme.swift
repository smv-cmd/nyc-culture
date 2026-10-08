import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    static let bg = Color(hex: 0x12151B)
    static let panel = Color(hex: 0x1A1E26)
    static let raise = Color(hex: 0x222733)
    static let line = Color(hex: 0x2B313D)
    static let fg = Color(hex: 0xEBE6DB)
    static let muted = Color(hex: 0x99A0AB)
    static let accent = Color(hex: 0xD9B56C)
    static let ok = Color(hex: 0x7FC79A)
    static let warn = Color(hex: 0xE3A45A)
    static let bad = Color(hex: 0xE07A6F)

    static let boroughs = ["Manhattan", "Brooklyn", "Queens"]

    static func borough(_ name: String) -> Color {
        switch name {
        case "Manhattan": return Color(hex: 0xE0A24F)
        case "Brooklyn": return Color(hex: 0x6FB3A6)
        case "Queens": return Color(hex: 0xA99BE0)
        default: return Color(hex: 0x9AA4B1)
        }
    }

    static func status(_ s: String?) -> Color {
        switch s {
        case "ok": return ok
        case "broken_url", "error": return bad
        default: return muted
        }
    }
}

extension Font {
    static let display = Font.system(.title2, design: .serif).weight(.semibold)
}
