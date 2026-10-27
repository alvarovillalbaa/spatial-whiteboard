import Foundation

public enum BoardGeometry {
    public static func shape(id: UUID = UUID(), kind: BoardKind, from: BoardPoint, to: BoardPoint, style: BoardStyle = BoardStyle(), text: String = "") throws -> BoardItem {
        try BoardValidation.point(from)
        try BoardValidation.point(to)
        guard kind != .stroke else { throw BoardError.invalid("Create a stroke from its world points.") }
        let frame = BoardRect(x: min(from.x, to.x), y: min(from.y, to.y),
                              width: max(kind == .text ? 160 : 1, abs(to.x - from.x)),
                              height: max(kind == .text ? 80 : 1, abs(to.y - from.y)))
        let points = kind == .arrow ? [normalized(from, in: frame), normalized(to, in: frame)] : []
        let item = BoardItem(id: id, kind: kind, frame: frame, points: points, text: text, style: style)
        try BoardValidation.item(item)
        return item
    }

    public static func stroke(id: UUID = UUID(), worldPoints: [BoardPoint], style: BoardStyle = BoardStyle()) throws -> BoardItem {
        guard (2...10_000).contains(worldPoints.count) else { throw BoardError.invalid("A stroke needs 2–10000 points.") }
        for point in worldPoints { try BoardValidation.point(point) }
        let first = worldPoints[0]
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for point in worldPoints.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        let frame = BoardRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        let item = BoardItem(id: id, kind: .stroke, frame: frame,
                             points: worldPoints.map { normalized($0, in: frame) }, style: style)
        try BoardValidation.item(item)
        return item
    }

    public static func hitTest(_ item: BoardItem, at point: BoardPoint, tolerance: Double) throws -> Bool {
        try BoardValidation.item(item)
        try BoardValidation.point(point)
        guard tolerance.isFinite, tolerance >= 0 else { throw BoardError.invalid("Selection tolerance must be finite and nonnegative.") }
        switch item.kind {
        case .rectangle, .text:
            return point.x >= item.frame.minX - tolerance && point.x <= item.frame.maxX + tolerance
                && point.y >= item.frame.minY - tolerance && point.y <= item.frame.maxY + tolerance
        case .ellipse:
            let radiusX = item.frame.width / 2 + tolerance
            let radiusY = item.frame.height / 2 + tolerance
            let dx = (point.x - item.frame.center.x) / radiusX
            let dy = (point.y - item.frame.center.y) / radiusY
            return dx * dx + dy * dy <= 1
        case .stroke, .arrow:
            let worldPoints = item.points.map { world($0, in: item.frame) }
            let reach = tolerance + item.style.strokeWidth / 2
            for index in 1..<worldPoints.count {
                if distance(from: point, toSegmentFrom: worldPoints[index - 1], to: worldPoints[index]) <= reach { return true }
            }
            if item.kind == .arrow {
                let wings = try arrowWings(from: worldPoints[0], to: worldPoints[1], width: item.style.strokeWidth)
                return wings.contains { distance(from: point, toSegmentFrom: worldPoints[1], to: $0) <= reach }
            }
            return false
        }
    }

    public static func bounds(of items: [BoardItem]) throws -> BoardRect? {
        guard items.count <= BoardValidation.maximumItems else { throw BoardError.invalid("A board can contain at most 500 objects.") }
        var result: BoardRect?
        for item in items {
            try BoardValidation.item(item)
            if let prior = result {
                let x = min(prior.minX, item.frame.minX), y = min(prior.minY, item.frame.minY)
                result = BoardRect(x: x, y: y, width: max(prior.maxX, item.frame.maxX) - x,
                                   height: max(prior.maxY, item.frame.maxY) - y)
            } else { result = item.frame }
        }
        return result
    }

    static func world(_ point: BoardPoint, in frame: BoardRect) -> BoardPoint {
        BoardPoint(x: frame.x + point.x * frame.width, y: frame.y + point.y * frame.height)
    }

    /// Shared native/SVG arrowhead geometry; a zero-length arrow has no wings.
    public static func arrowWings(from start: BoardPoint, to end: BoardPoint, width: Double) throws -> [BoardPoint] {
        try BoardValidation.point(start)
        try BoardValidation.point(end)
        guard width.isFinite, (1...12).contains(width) else { throw BoardError.invalid("Arrow stroke width must be 1–12.") }
        let dx = end.x - start.x, dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return [] }
        let head = min(length, 10 + width * 2)
        let ux = dx / length, uy = dy / length
        return [-1.0, 1.0].map { direction in
            BoardPoint(x: end.x - head * ux + direction * head * uy / 2,
                       y: end.y - head * uy - direction * head * ux / 2)
        }
    }

    private static func normalized(_ point: BoardPoint, in frame: BoardRect) -> BoardPoint {
        BoardPoint(x: (point.x - frame.x) / frame.width, y: (point.y - frame.y) / frame.height)
    }

    private static func distance(from point: BoardPoint, toSegmentFrom start: BoardPoint, to end: BoardPoint) -> Double {
        let dx = end.x - start.x, dy = end.y - start.y
        let squaredLength = dx * dx + dy * dy
        guard squaredLength > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / squaredLength))
        return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy))
    }
}
