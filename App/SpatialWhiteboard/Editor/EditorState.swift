import SwiftUI
import Observation
import BoardCore

@Observable
@MainActor
final class EditorState {
    private(set) var board: Board
    private(set) var generation = UUID()
    var tool: EditorTool = .select
    private(set) var selectedIDs: Set<UUID> = []
    private(set) var isSelectingMultiple = false
    var style = BoardStyle()
    var viewport = BoardViewport()
    var canvasSize = CGSize.zero
    var gesture: CanvasGesture?
    var gestureInProgress = false
    var gestureBlocked = false
    var interactionID: UUID?
    var issue: EditorIssue?
    var itemEditor: ItemEditorContext?
    var selectionEditor: SelectionMoveContext?
    var titleEditor: BoardTitleContext?
    var showObjects = true
    var showInspector = true
    var canUndo = false
    var canRedo = false

    init(board: Board) {
        self.board = board
    }

    var stamp: EditStamp {
        EditStamp(boardID: board.id, revision: board.revision, generation: generation)
    }

    var selectedItem: BoardItem? {
        guard selectedIDs.count == 1 else { return nil }
        return selectedItems.first
    }

    var selectedItems: [BoardItem] {
        board.items.filter { selectedIDs.contains($0.id) }
    }

    var selectedBounds: BoardRect? {
        try? BoardGeometry.bounds(of: selectedItems)
    }

    func receive(_ incoming: Board) {
        guard incoming != board else { return }
        board = incoming
        generation = UUID()
        selectedIDs.removeAll()
        cancelGesture()
        // Receiving a document change never writes back to its binding.
    }

    func perform(_ edit: BoardEdit, stamp expected: EditStamp, source: Board) throws -> Board {
        receive(source)
        guard expected == stamp else {
            throw BoardError.invalid("The document changed while you were editing. Cancel and reopen the editor, or try the action again.")
        }
        try validateSelection(for: edit)
        // FileDocument's binding owns system undo. History is used only to validate this transaction.
        var transaction = try BoardHistory(board: source)
        try transaction.perform(edit, expectedRevision: expected.revision)
        let result = transaction.board
        if result != board {
            board = result
            generation = UUID()
            cancelGesture()
            switch edit {
            case .add(let item): selectedIDs = [item.id]
            case .duplicate(_, let id, _): selectedIDs = [id]
            case .duplicateMany(_, let ids, _): selectedIDs = Set(ids)
            default: break
            }
            selectedIDs.formIntersection(Set(result.items.map(\.id)))
        }
        return result
    }

    func choose(_ tool: EditorTool) {
        cancelGesture()
        self.tool = tool
    }

    func select(_ id: UUID?) {
        if let id, !board.items.contains(where: { $0.id == id }) { return }
        cancelGesture()
        selectedIDs = id.map { Set([$0]) } ?? []
        tool = .select
    }

    func selectFromList(_ id: UUID) {
        guard board.items.contains(where: { $0.id == id }) else { return }
        cancelGesture()
        if isSelectingMultiple {
            if !selectedIDs.insert(id).inserted { selectedIDs.remove(id) }
        } else { selectedIDs = [id] }
        tool = .select
    }

    func setMultipleSelection(_ enabled: Bool) {
        cancelGesture()
        isSelectingMultiple = enabled
        tool = .select
    }

    func selectAll() {
        cancelGesture()
        selectedIDs = Set(board.items.map(\.id))
        isSelectingMultiple = true
        tool = .select
    }

    func clearSelection() {
        cancelGesture()
        selectedIDs.removeAll()
    }

    // Gesture initialization already owns the interaction; it must not cancel itself.
    func setGestureSelection(_ ids: Set<UUID>) throws {
        guard ids.isSubset(of: Set(board.items.map(\.id))) else { throw BoardError.missingItem }
        selectedIDs = ids
    }

    func editSelected() {
        guard let item = selectedItem else { return }
        cancelGesture()
        itemEditor = ItemEditorContext(item: item, isNew: false, stamp: stamp)
    }

    func moveSelection() {
        guard selectedItems.count > 1 else { return }
        cancelGesture()
        do {
            guard let bounds = try BoardGeometry.bounds(of: selectedItems) else { return }
            selectionEditor = SelectionMoveContext(ids: selectedItems.map(\.id), bounds: bounds, stamp: stamp)
        } catch { report(error) }
    }

    func report(_ error: Error) {
        issue = EditorIssue(message: error.localizedDescription)
    }

    func zoom(by factor: Double) {
        cancelGesture()
        viewport.zoom(by: factor)
    }

    func fit() {
        cancelGesture()
        do { viewport.fit(try BoardGeometry.bounds(of: board.items), in: canvasSize) }
        catch { report(error) }
    }

    func resetView() {
        cancelGesture()
        viewport = BoardViewport()
    }

    func insertionPoint() -> BoardPoint {
        viewport.worldPoint(CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2), in: canvasSize)
    }

    func cancelGesture() {
        if gestureInProgress { gestureBlocked = true }
        gesture = nil
    }

    func endInteraction() {
        gesture = nil
        gestureInProgress = false
        gestureBlocked = false
        interactionID = nil
    }

    func historyDidChange() {
        generation = UUID()
        selectedIDs.removeAll()
        cancelGesture()
    }

    private func validateSelection(for edit: BoardEdit) throws {
        let ids: [UUID]
        switch edit {
        case .move(let selected, _), .deleteMany(let selected),
             .duplicateMany(let selected, _, _), .bringToFrontMany(let selected),
             .sendToBackMany(let selected): ids = selected
        default: return
        }
        guard ids.count == selectedIDs.count, Set(ids) == selectedIDs else {
            throw BoardError.invalid("The selection changed while this action was open. Close it and try again.")
        }
    }

    func prepareObject(_ kind: BoardKind) throws -> BoardItem {
        let point = insertionPoint()
        return try BoardGeometry.shape(kind: kind, from: point,
                                       to: BoardPoint(x: point.x + 180, y: point.y + 110), style: style)
    }
}
