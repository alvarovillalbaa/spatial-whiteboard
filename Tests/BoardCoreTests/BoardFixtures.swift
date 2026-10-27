import Foundation
import BoardCore

enum BoardFixtures {
    static func id(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    static func rectangle(_ value: Int = 1) -> BoardItem {
        BoardItem(id: id(value), frame: BoardRect(x: 10, y: 20, width: 100, height: 80))
    }

    static func stroke(_ value: Int = 1, count: Int = 2) -> BoardItem {
        BoardItem(id: id(value), kind: .stroke, frame: BoardRect(width: 100, height: 100),
                  points: (0..<count).map { BoardPoint(x: Double($0 % 100) / 99, y: Double($0 % 2)) })
    }

    static func text(_ value: Int = 1, content: String = "A note") -> BoardItem {
        BoardItem(id: id(value), kind: .text, frame: BoardRect(width: 200, height: 100), text: content)
    }

    static func object(_ board: Board) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: BoardCodec.encode(board)) as! [String: Any]
    }

    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    // Valid combining sequences exercise encoded byte size independently from
    // grapheme limits. The final board is exactly the native byte cap.
    static func exactSizeBoard(revision: Int) throws -> Board {
        let content = "a" + String(repeating: "\u{301}", count: 3800)
        var board = Board(id: id(999), revision: revision, items: (1...500).map { text($0, content: content) })
        var remaining = 4 * 1024 * 1024 - (try BoardCodec.encode(board)).count
        for index in board.items.indices where remaining > 0 {
            let addition = min(50_000, remaining)
            board.items[index].text += String(repeating: "\u{301}", count: addition / 2)
            if addition % 2 == 1 { board.items[index].text += "b" }
            remaining -= addition
        }
        precondition(remaining == 0)
        return board
    }
}
