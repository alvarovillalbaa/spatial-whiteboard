import SwiftUI
import Observation
import BoardCore

@Observable
@MainActor
final class EditorState {
    private(set) var board: Board
    private(set) var generation = UUID()
    var tool: EditorTool = .select
    var selectedID: UUID?
    var style = BoardStyle()
    var viewport = BoardViewport()
    var canvasSize = CGSize.zero
    var gesture: CanvasGesture?
    var gestureInProgress = false
    var gestureBlocked = false
    var interactionID: UUID?
    var issue: EditorIssue?
    var itemEditor: ItemEditorContext?
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
        board.items.first { $0.id == selectedID }
    }

    func receive(_ incoming: Board) {
        guard incoming != board else { return }
        board = incoming
        generation = UUID()
        selectedID = nil
        cancelGesture()
        // Receiving a document change never writes back to its binding.
    }

    func perform(_ edit: BoardEdit, stamp expected: EditStamp, source: Board) throws -> Board {
        receive(source)
        guard expected == stamp else {
            throw BoardError.invalid("The document changed while you were editing. Cancel and reopen the editor, or try the action again.")
        }
        // FileDocument's binding owns system undo. History is used only to validate this transaction.
        var transaction = try BoardHistory(board: source)
        try transaction.perform(edit, expectedRevision: expected.revision)
        let result = transaction.board
        if result != board {
            board = result
            generation = UUID()
            cancelGesture()
            switch edit {
            case .add(let item): selectedID = item.id
            case .duplicate(_, let id, _): selectedID = id
            default: break
            }
            if !result.items.contains(where: { $0.id == selectedID }) { selectedID = nil }
        }
        return result
    }

    func choose(_ tool: EditorTool) {
        cancelGesture()
        self.tool = tool
    }

    func select(_ id: UUID?) {
        cancelGesture()
        selectedID = id
        tool = .select
    }

    func editSelected() {
        guard let item = selectedItem else { return }
        cancelGesture()
        itemEditor = ItemEditorContext(item: item, isNew: false, stamp: stamp)
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
        selectedID = nil
        cancelGesture()
    }

    func prepareObject(_ kind: BoardKind) throws -> BoardItem {
        let point = insertionPoint()
        return try BoardGeometry.shape(kind: kind, from: point,
                                       to: BoardPoint(x: point.x + 180, y: point.y + 110), style: style)
    }
}
