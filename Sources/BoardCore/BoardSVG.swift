import Foundation

public enum BoardSVG {
    public static func encode(_ board: Board) throws -> Data {
        // Export obeys the same complete-state and size boundary as native saves.
        _ = try BoardCodec.encode(board)
        let bounds = try BoardGeometry.bounds(of: board.items)
        let viewBox = bounds.map { BoardRect(x: $0.x - 40, y: $0.y - 40, width: $0.width + 80, height: $0.height + 80) }
            ?? BoardRect(x: 0, y: 0, width: 1024, height: 768)
        var lines = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
                     "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(n(viewBox.x)) \(n(viewBox.y)) \(n(viewBox.width)) \(n(viewBox.height))\" width=\"\(n(viewBox.width))\" height=\"\(n(viewBox.height))\" role=\"img\">",
                     "<title>\(escape(board.title))</title>"]
        for item in board.items { lines.append(try element(item)) }
        lines.append("</svg>")
        return Data(lines.joined(separator: "\n").utf8)
    }

    private static func element(_ item: BoardItem) throws -> String {
        let frame = item.frame
        let color = item.style.ink.svgColor
        let stroke = "stroke=\"\(color)\" stroke-width=\"\(n(item.style.strokeWidth))\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
        let fill = item.style.fill ? "fill=\"\(color)\" fill-opacity=\"0.15\"" : "fill=\"none\""
        switch item.kind {
        case .rectangle:
            return "<rect x=\"\(n(frame.x))\" y=\"\(n(frame.y))\" width=\"\(n(frame.width))\" height=\"\(n(frame.height))\" \(stroke) \(fill)/>"
        case .ellipse:
            return "<ellipse cx=\"\(n(frame.center.x))\" cy=\"\(n(frame.center.y))\" rx=\"\(n(frame.width / 2))\" ry=\"\(n(frame.height / 2))\" \(stroke) \(fill)/>"
        case .stroke, .arrow:
            let points = item.points.map { BoardGeometry.world($0, in: frame) }
            let line = "<polyline points=\"\(pairs(points))\" \(stroke) fill=\"none\"/>"
            guard item.kind == .arrow else { return line }
            let wings = try BoardGeometry.arrowWings(from: points[0], to: points[1], width: item.style.strokeWidth)
            guard wings.count == 2 else { return line }
            return line + "\n<polyline points=\"\(pairs([wings[0], points[1], wings[1]]))\" \(stroke) fill=\"none\"/>"
        case .text:
            let clipID = "text-\(item.id.uuidString)"
            let content = item.text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
                .components(separatedBy: "\n").enumerated().map { index, line in
                    "<tspan x=\"\(n(frame.x))\" dy=\"\(n(index == 0 ? 0 : item.style.fontSize * 1.25))\">\(escape(line))</tspan>"
                }.joined()
            return "<defs><clipPath id=\"\(clipID)\"><rect x=\"\(n(frame.x))\" y=\"\(n(frame.y))\" width=\"\(n(frame.width))\" height=\"\(n(frame.height))\"/></clipPath></defs>\n"
                + "<text x=\"\(n(frame.x))\" y=\"\(n(frame.y + item.style.fontSize))\" fill=\"\(color)\" font-family=\"system-ui,sans-serif\" font-size=\"\(n(item.style.fontSize))\" xml:space=\"preserve\" clip-path=\"url(#\(clipID))\">\(content)</text>"
        }
    }

    private static func pairs(_ points: [BoardPoint]) -> String {
        points.map { "\(n($0.x)),\(n($0.y))" }.joined(separator: " ")
    }

    private static func n(_ value: Double) -> String { value == 0 ? "0" : String(value) }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
