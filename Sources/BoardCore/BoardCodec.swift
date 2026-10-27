import Foundation

public enum BoardCodec {
    public static func encode(_ board: Board) throws -> Data {
        try BoardValidation.board(board)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(board)
        guard data.count <= BoardValidation.maximumBytes else { throw BoardError.invalid("Board documents must be at most 4 MB.") }
        return data
    }

    public static func decode(_ data: Data) throws -> Board {
        guard data.count <= BoardValidation.maximumBytes else { throw BoardError.invalid("Board documents must be at most 4 MB.") }
        guard !data.contains(0), String(data: data, encoding: .utf8) != nil else { throw BoardError.invalid("Board documents must use UTF-8 JSON.") }
        let input = data.starts(with: [0xEF, 0xBB, 0xBF]) ? Data(data.dropFirst(3)) : data
        do {
            try JSONStructure.validate(input)
            let root = try JSONSerialization.jsonObject(with: input)
            try schema(root)
            let board = try JSONDecoder().decode(Board.self, from: input)
            try BoardValidation.board(board)
            return board
        } catch let error as BoardError { throw error }
        catch { throw BoardError.invalid("This is not a supported board document. Keep the original file for recovery.") }
    }

    private static func schema(_ value: Any) throws {
        let board = try object(value, allowed: ["version", "id", "title", "revision", "items"])
        guard let items = board["items"] as? [Any], items.count <= BoardValidation.maximumItems else { throw invalid() }
        var pointCount = 0
        for value in items {
            let item = try object(value, allowed: ["id", "kind", "frame", "points", "text", "style"])
            guard let frame = item["frame"], let style = item["style"] else { throw invalid() }
            _ = try object(frame, allowed: ["x", "y", "width", "height"])
            _ = try object(style, allowed: ["ink", "fill", "strokeWidth", "fontSize"])
            guard let points = item["points"] as? [Any], points.count <= 10_000 else { throw invalid() }
            pointCount += points.count
            guard pointCount <= BoardValidation.maximumPoints else { throw invalid() }
            for point in points { _ = try object(point, allowed: ["x", "y"]) }
        }
    }

    private static func object(_ value: Any, allowed: Set<String>) throws -> [String: Any] {
        guard let result = value as? [String: Any], Set(result.keys).isSubset(of: allowed) else { throw invalid() }
        return result
    }

    private static func invalid() -> BoardError { .invalid("The board contains unsupported or incomplete fields.") }
}
