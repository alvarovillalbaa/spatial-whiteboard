import SwiftUI
import BoardCore

extension BoardInk {
    var title: String { rawValue.capitalized }

    var color: Color {
        let hex: UInt32
        switch self {
        case .graphite: hex = 0x243247
        case .teal: hex = 0x087F8C
        case .blue: hex = 0x2563EB
        case .orange: hex = 0xC66A13
        case .rose: hex = 0xBE3B65
        }
        return Color(red: Double((hex >> 16) & 255) / 255,
                     green: Double((hex >> 8) & 255) / 255,
                     blue: Double(hex & 255) / 255)
    }
}

extension BoardKind {
    var title: String { self == .stroke ? "Pen stroke" : rawValue.capitalized }

    var symbol: String {
        switch self {
        case .stroke: return "scribble.variable"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        }
    }
}

extension BoardItem {
    var displayName: String {
        if kind == .text, !text.isEmpty { return String(text.prefix(60)) }
        return kind.title
    }
}

enum BoardPresentation {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US_POSIX")))
    }

    static func exportName(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = title.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
        let name = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Board" : String(name.prefix(80))
    }
}
