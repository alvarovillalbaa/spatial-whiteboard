import Foundation

public enum BoardEdit: Equatable, Sendable {
    case add(BoardItem)
    case replace(BoardItem)
    case delete(UUID)
    case duplicate(id: UUID, newID: UUID, offset: BoardPoint)
    case bringToFront(UUID)
    case sendToBack(UUID)
    case move(ids: [UUID], offset: BoardPoint)
    case deleteMany([UUID])
    case duplicateMany(ids: [UUID], newIDs: [UUID], offset: BoardPoint)
    case bringToFrontMany([UUID])
    case sendToBackMany([UUID])
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
        case .move(let ids, let offset):
            let selected = try selection(ids)
            try BoardGeometry.validateTranslation(offset)
            candidate.items = try board.items.map { item in
                guard selected.contains(item.id) else { return item }
                return try BoardGeometry.translated(item, by: offset)
            }
        case .deleteMany(let ids):
            let selected = try selection(ids)
            candidate.items.removeAll { selected.contains($0.id) }
        case .duplicateMany(let ids, let newIDs, let offset):
            guard ids.count == newIDs.count else { throw BoardError.invalid("Every duplicated object needs one new ID.") }
            _ = try selection(ids)
            try BoardGeometry.validateTranslation(offset)
            let replacements = Set(newIDs)
            guard replacements.count == newIDs.count,
                  replacements.isDisjoint(with: Set(board.items.map(\.id))) else {
                throw BoardError.invalid("Duplicated objects need unique new IDs that are not already on the board.")
            }
            let mapping = Dictionary(uniqueKeysWithValues: zip(ids, newIDs))
            for item in board.items {
                guard let newID = mapping[item.id] else { continue }
                var copy = try BoardGeometry.translated(item, by: offset)
                copy.id = newID
                candidate.items.append(copy)
            }
        case .bringToFrontMany(let ids):
            let selected = try selection(ids)
            candidate.items = board.items.filter { !selected.contains($0.id) }
                + board.items.filter { selected.contains($0.id) }
        case .sendToBackMany(let ids):
            let selected = try selection(ids)
            candidate.items = board.items.filter { selected.contains($0.id) }
                + board.items.filter { !selected.contains($0.id) }
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

    private func selection(_ ids: [UUID]) throws -> Set<UUID> {
        guard ids.count <= BoardValidation.maximumItems else { throw BoardError.invalid("A selection can contain at most 500 objects.") }
        let selected = Set(ids)
        guard selected.count == ids.count else { throw BoardError.invalid("A selection cannot repeat an object ID.") }
        guard selected.isSubset(of: Set(board.items.map(\.id))) else { throw BoardError.missingItem }
        return selected
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
