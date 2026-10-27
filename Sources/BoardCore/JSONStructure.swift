import Foundation

/// An iterative lexical guard runs before Foundation's recursive JSON parser.
/// It bounds nesting and retains keys that dictionary decoding would collapse.
enum JSONStructure {
    private struct Frame {
        let isObject: Bool
        var expectsKey: Bool
        var keys: Set<String> = []
    }

    static func validate(_ data: Data) throws {
        let bytes = Array(data)
        var frames: [Frame] = []
        var index = 0
        let keyDecoder = JSONDecoder()
        while index < bytes.count {
            switch bytes[index] {
            case 0x7b, 0x5b:
                guard frames.count < 16 else { throw invalid("The board JSON is nested too deeply.") }
                let isObject = bytes[index] == 0x7b
                frames.append(Frame(isObject: isObject, expectsKey: isObject))
                index += 1
            case 0x7d, 0x5d:
                guard let last = frames.last, last.isObject == (bytes[index] == 0x7d) else { throw invalid("The board JSON has mismatched containers.") }
                frames.removeLast()
                index += 1
            case 0x2c:
                if let last = frames.indices.last, frames[last].isObject { frames[last].expectsKey = true }
                index += 1
            case 0x3a:
                if let last = frames.indices.last, frames[last].isObject { frames[last].expectsKey = false }
                index += 1
            case 0x22:
                let end = try stringEnd(in: bytes, from: index)
                if let last = frames.indices.last, frames[last].isObject && frames[last].expectsKey {
                    let key = try keyDecoder.decode(String.self, from: Data(bytes[index...end]))
                    guard key.utf8.count <= 64, frames[last].keys.count < 32 else { throw invalid("The board JSON contains unsupported fields.") }
                    guard frames[last].keys.insert(key).inserted else { throw invalid("The board JSON contains duplicate fields.") }
                    frames[last].expectsKey = false
                }
                index = end + 1
            default:
                index += 1
            }
        }
        guard frames.isEmpty else { throw invalid("The board JSON is incomplete.") }
    }

    private static func stringEnd(in bytes: [UInt8], from start: Int) throws -> Int {
        var index = start + 1
        while index < bytes.count {
            if bytes[index] == 0x5c { index += 2 }
            else if bytes[index] == 0x22 { return index }
            else { index += 1 }
        }
        throw invalid("The board JSON contains an unfinished string.")
    }

    private static func invalid(_ message: String) -> BoardError { .invalid(message) }
}
