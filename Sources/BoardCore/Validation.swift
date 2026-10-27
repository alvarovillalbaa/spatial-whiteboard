import Foundation

enum BoardValidation {
    static let maximumBytes = 4 * 1024 * 1024
    static let maximumItems = 500
    static let maximumPoints = 50_000

    static func board(_ board: Board) throws {
        guard board.version == 1 else { throw BoardError.invalid("This board version is not supported.") }
        guard board.revision >= 0 else { throw BoardError.invalid("Board revisions cannot be negative.") }
        try title(board.title)
        guard board.items.count <= maximumItems else { throw BoardError.invalid("A board can contain at most 500 objects.") }
        var ids = Set<UUID>()
        var pointCount = 0
        for item in board.items {
            guard ids.insert(item.id).inserted else { throw BoardError.invalid("The board contains duplicate object IDs.") }
            try self.item(item)
            pointCount += item.points.count
            guard pointCount <= maximumPoints else { throw BoardError.invalid("A board can contain at most 50000 points.") }
        }
    }

    static func title(_ title: String) throws {
        guard title.utf8.count <= 4096, title.count <= 80,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isXMLText(title) else { throw BoardError.invalid("Use a board title of 1–80 characters without unsupported control characters.") }
    }

    static func item(_ item: BoardItem) throws {
        try rect(item.frame)
        try style(item.style)
        switch item.kind {
        case .stroke:
            guard (2...10_000).contains(item.points.count), item.text.isEmpty else { throw BoardError.invalid("A stroke needs 2–10000 points and no text.") }
        case .arrow:
            guard item.points.count == 2, item.text.isEmpty else { throw BoardError.invalid("An arrow needs exactly two points and no text.") }
        case .rectangle, .ellipse:
            guard item.points.isEmpty, item.text.isEmpty else { throw BoardError.invalid("Shapes cannot contain points or text.") }
        case .text:
            guard item.points.isEmpty, item.text.utf8.count <= 65_536, item.text.count <= 1000,
                  isXMLText(item.text) else { throw BoardError.invalid("Text objects support at most 1000 characters without unsupported control characters.") }
        }
        for point in item.points {
            guard point.x.isFinite, point.y.isFinite, (0...1).contains(point.x), (0...1).contains(point.y) else {
                throw BoardError.invalid("Object points must be normalized within their frame.")
            }
        }
    }

    static func point(_ point: BoardPoint) throws {
        guard coordinate(point.x), coordinate(point.y) else { throw BoardError.invalid("Board coordinates must be finite and within −100000…100000.") }
    }

    static func rect(_ rect: BoardRect) throws {
        guard coordinate(rect.x), coordinate(rect.y), coordinate(rect.maxX), coordinate(rect.maxY),
              rect.width.isFinite, rect.height.isFinite, (1...200_000).contains(rect.width), (1...200_000).contains(rect.height) else {
            throw BoardError.invalid("Object frames must have positive bounded dimensions and finite board edges.")
        }
    }

    static func style(_ style: BoardStyle) throws {
        guard style.strokeWidth.isFinite, (1...12).contains(style.strokeWidth),
              style.fontSize.isFinite, (12...96).contains(style.fontSize) else { throw BoardError.invalid("Stroke width must be 1–12 and text size 12–96.") }
    }

    private static func coordinate(_ value: Double) -> Bool {
        value.isFinite && (-100_000...100_000).contains(value)
    }

    private static func isXMLText(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy {
            let scalar = $0.value
            return scalar == 9 || scalar == 10 || scalar == 13 || (0x20...0xD7FF).contains(scalar)
                || (0xE000...0xFFFD).contains(scalar) || (0x10000...0x10FFFF).contains(scalar)
        }
    }
}
