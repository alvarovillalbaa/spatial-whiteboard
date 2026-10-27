import Foundation

public enum BoardEdit: Equatable, Sendable {
    case add(BoardItem)
    case replace(BoardItem)
    case delete(UUID)
    case duplicate(id: UUID, newID: UUID, offset: BoardPoint)
    case bringToFront(UUID)
    case sendToBack(UUID)
    case rename(String)
}

public struct BoardHistory: Sendable {
    public private(set) var board: Board
    private var past: [Board] = []
    private var future: [Board] = []

    public init(board: Board = Board()) throws {
        _ = try BoardCodec.encode(board)
        self.board = board
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    public mutating func perform(_ edit: BoardEdit, expectedRevision: Int) throws {
        try checkRevision(expectedRevision)
        var candidate = board
        switch edit {
        case .add(let item):
            candidate.items.append(item)
        case .replace(let item):
            let index = try index(of: item.id)
            candidate.items[index] = item
        case .delete(let id):
            candidate.items.remove(at: try index(of: id))
        case .duplicate(let id, let newID, let offset):
            try BoardValidation.point(offset)
            var item = board.items[try index(of: id)]
            item.id = newID
            item.frame.x += offset.x
            item.frame.y += offset.y
            candidate.items.append(item)
        case .bringToFront(let id):
            let item = candidate.items.remove(at: try index(of: id))
            candidate.items.append(item)
        case .sendToBack(let id):
            let item = candidate.items.remove(at: try index(of: id))
            candidate.items.insert(item, at: 0)
        case .rename(let title):
            candidate.title = title
        }
        guard candidate != board else { return }
        candidate.revision = try nextRevision()
        _ = try BoardCodec.encode(candidate)
        past.append(board)
        if past.count > 20 { past.removeFirst() }
        future.removeAll()
        board = candidate
    }

    public mutating func undo(expectedRevision: Int) throws {
        try checkRevision(expectedRevision)
        guard var candidate = past.last else { throw BoardError.historyUnavailable }
        candidate.revision = try nextRevision()
        _ = try BoardCodec.encode(candidate)
        future.append(board)
        past.removeLast()
        board = candidate
    }

    public mutating func redo(expectedRevision: Int) throws {
        try checkRevision(expectedRevision)
        guard var candidate = future.last else { throw BoardError.historyUnavailable }
        candidate.revision = try nextRevision()
        _ = try BoardCodec.encode(candidate)
        past.append(board)
        future.removeLast()
        board = candidate
    }

    private func index(of id: UUID) throws -> Int {
        guard let index = board.items.firstIndex(where: { $0.id == id }) else { throw BoardError.missingItem }
        return index
    }

    private func checkRevision(_ expected: Int) throws {
        guard expected == board.revision else { throw BoardError.staleRevision }
    }

    private func nextRevision() throws -> Int {
        let (revision, overflow) = board.revision.addingReportingOverflow(1)
        guard !overflow else { throw BoardError.revisionOverflow }
        return revision
    }
}
