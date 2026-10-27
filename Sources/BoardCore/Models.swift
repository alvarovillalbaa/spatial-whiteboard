import Foundation

public struct BoardPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }
}

public struct BoardRect: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double = 0, y: Double = 0, width: Double = 1, height: Double = 1) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var center: BoardPoint { BoardPoint(x: x + width / 2, y: y + height / 2) }
}

public enum BoardKind: String, Codable, CaseIterable, Hashable, Sendable {
    case stroke, rectangle, ellipse, arrow, text
}

public enum BoardInk: String, Codable, CaseIterable, Hashable, Sendable {
    case graphite, teal, blue, orange, rose

    public var svgColor: String {
        switch self {
        case .graphite: return "#243247"
        case .teal: return "#087F8C"
        case .blue: return "#2563EB"
        case .orange: return "#C66A13"
        case .rose: return "#BE3B65"
        }
    }
}

public struct BoardStyle: Codable, Equatable, Hashable, Sendable {
    public var ink: BoardInk
    public var fill: Bool
    public var strokeWidth: Double
    public var fontSize: Double

    public init(ink: BoardInk = .graphite, fill: Bool = false, strokeWidth: Double = 3, fontSize: Double = 24) {
        self.ink = ink
        self.fill = fill
        self.strokeWidth = strokeWidth
        self.fontSize = fontSize
    }
}

public struct BoardItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: BoardKind
    public var frame: BoardRect
    public var points: [BoardPoint]
    public var text: String
    public var style: BoardStyle

    public init(id: UUID = UUID(), kind: BoardKind = .rectangle, frame: BoardRect = BoardRect(), points: [BoardPoint] = [], text: String = "", style: BoardStyle = BoardStyle()) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.points = points
        self.text = text
        self.style = style
    }
}

public struct Board: Codable, Equatable, Sendable {
    public var version: Int
    public var id: UUID
    public var title: String
    public var revision: Int
    public var items: [BoardItem]

    public init(version: Int = 1, id: UUID = UUID(), title: String = "Untitled Board", revision: Int = 0, items: [BoardItem] = []) {
        self.version = version
        self.id = id
        self.title = title
        self.revision = revision
        self.items = items
    }
}

public enum BoardError: Error, Equatable, LocalizedError, Sendable {
    case invalid(String)
    case staleRevision
    case missingItem
    case historyUnavailable
    case revisionOverflow

    public var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .staleRevision: return "The board changed. Try the action again on its current state."
        case .missingItem: return "That object is no longer on the board."
        case .historyUnavailable: return "There is no matching history action available."
        case .revisionOverflow: return "This board has reached its revision limit. Export or copy its contents to a new board."
        }
    }
}
