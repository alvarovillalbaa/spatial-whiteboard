// T2: actual editor/core value state with authored objects; no window or document access.
import Foundation
import SwiftUI
import BoardCore
import Darwin

private struct EditorCheckFailure: Error, CustomStringConvertible {
    let description: String
}

private struct EditorCheck {
    let name: String
    let run: @MainActor () throws -> Void

    init(_ name: String, run: @escaping @MainActor () throws -> Void) {
        self.name = name
        self.run = run
    }
}

private struct EditorCheckResult: Encodable {
    let name: String
    let status: String
    let failure: String?
}

private struct EditorCheckReport: Encodable {
    let schemaVersion: Int
    let kind: String
    let status: String
    let expectedCases: Int
    let passed: Int
    let failed: Int
    let cases: [EditorCheckResult]
    let limits: [String]
}

@MainActor
private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw EditorCheckFailure(description: message) }
}

@MainActor
private func requireThrows(_ message: String, _ action: @MainActor () throws -> Void) throws {
    do { try action() }
    catch { return }
    throw EditorCheckFailure(description: message)
}

private func fixtureID(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
}

private func fixtureBoard() -> Board {
    Board(id: fixtureID(99), title: "Authored selection fixture", items: [
        BoardItem(id: fixtureID(1), kind: .rectangle, frame: BoardRect(x: 10, y: 20, width: 30, height: 40)),
        BoardItem(id: fixtureID(2), kind: .ellipse, frame: BoardRect(x: 70, y: 30, width: 20, height: 30)),
        BoardItem(id: fixtureID(3), kind: .rectangle, frame: BoardRect(x: 120, y: -10, width: 40, height: 20))
    ])
}

@MainActor
private func selectedEditor(_ ids: Set<UUID> = [fixtureID(1), fixtureID(3)]) throws -> EditorState {
    let editor = EditorState(board: fixtureBoard())
    editor.setMultipleSelection(true)
    try editor.setGestureSelection(ids)
    return editor
}

// Constructing an actual captured draft tests finishGesture, not OS gesture delivery.
@MainActor
private func installDraft(_ editor: EditorState, hitID: UUID?, before: Set<UUID>? = nil,
                          dragged: Bool = false, offset: BoardPoint = BoardPoint()) throws {
    let start = BoardPoint(x: 0, y: 0)
    var draft = CanvasGesture(stamp: editor.stamp, tool: editor.tool,
                              selectedIDs: editor.selectedIDs,
                              selectionBefore: before ?? editor.selectedIDs,
                              hitID: hitID, selectsMultiple: editor.isSelectingMultiple,
                              objectID: fixtureID(90), start: start,
                              viewport: editor.viewport, style: editor.style,
                              originals: hitID == nil ? [] : editor.selectedItems,
                              points: [start])
    draft.hasDragged = dragged
    draft.offset = offset
    if dragged, !draft.originals.isEmpty {
        draft.previews = try draft.originals.map { try BoardGeometry.translated($0, by: offset) }
    }
    editor.gesture = draft
    editor.gestureInProgress = true
    editor.gestureBlocked = false
    editor.interactionID = UUID()
}

@main
private struct MultiSelectionChecks {
    @MainActor
    static func main() {
        let checks: [EditorCheck] = [
            EditorCheck("single selection exposes one item without editing the board") {
                let board = fixtureBoard()
                let editor = EditorState(board: board)
                let stamp = editor.stamp
                editor.select(fixtureID(2))
                try require(editor.selectedIDs == [fixtureID(2)], "The selected ID did not match the chosen object")
                try require(editor.selectedItem == board.items[1], "Single selection did not expose its actual item")
                try require(editor.board == board && editor.stamp == stamp, "Selection mutated persistent state or its document stamp")
                editor.select(nil)
                try require(editor.selectedIDs.isEmpty && editor.selectedItem == nil, "Clearing single selection left an item selected")
            },
            EditorCheck("multiple list selection toggles membership in board order") {
                let editor = EditorState(board: fixtureBoard())
                let before = editor.board
                editor.setMultipleSelection(true)
                editor.selectFromList(fixtureID(3))
                editor.selectFromList(fixtureID(1))
                try require(editor.selectedItems.map(\.id) == [fixtureID(1), fixtureID(3)], "Selection order followed tap order instead of board order")
                try require(editor.selectedItem == nil, "A group incorrectly exposed a single selected item")
                try require(editor.selectedBounds == BoardRect(x: 10, y: -10, width: 150, height: 70), "Aggregate bounds did not include the complete selection")
                editor.selectFromList(fixtureID(1))
                try require(editor.selectedIDs == [fixtureID(3)], "A second list activation did not remove its member")
                try require(editor.board == before, "List selection wrote persistent board state")
            },
            EditorCheck("select all and clear remain transient selection actions") {
                let editor = EditorState(board: fixtureBoard())
                let board = editor.board
                let stamp = editor.stamp
                editor.selectAll()
                try require(editor.isSelectingMultiple && editor.tool == .select, "Select All did not enable the selection controls")
                try require(editor.selectedItems.map(\.id) == board.items.map(\.id), "Select All did not preserve board order")
                editor.clearSelection()
                try require(editor.selectedIDs.isEmpty && editor.selectedBounds == nil, "Clear Selection retained selected content")
                try require(editor.board == board && editor.stamp == stamp, "Transient selection consumed a document revision")
            },
            EditorCheck("unknown selection IDs cannot replace a valid selection") {
                let editor = try selectedEditor([fixtureID(1)])
                let before = editor.board
                try requireThrows("An unknown gesture selection was accepted") {
                    try editor.setGestureSelection([fixtureID(1), fixtureID(404)])
                }
                try require(editor.selectedIDs == [fixtureID(1)], "Failed gesture selection partially changed membership")
                editor.select(fixtureID(404))
                editor.selectFromList(fixtureID(404))
                try require(editor.selectedIDs == [fixtureID(1)] && editor.board == before, "An obsolete list/selection ID changed current state")
            },
            EditorCheck("selected members move in one editor transaction") {
                let editor = try selectedEditor()
                let before = editor.board
                let stamp = editor.stamp
                let result = try editor.perform(.move(ids: [fixtureID(3), fixtureID(1)], offset: BoardPoint(x: 12, y: -8)), stamp: stamp, source: before)
                try require(result.revision == before.revision + 1, "A batch move consumed more than one revision")
                try require(result.items[0].frame.x == 22 && result.items[0].frame.y == 12, "First selected member did not receive the shared offset")
                try require(result.items[2].frame.x == 132 && result.items[2].frame.y == -18, "Second selected member did not receive the same offset")
                try require(result.items[1] == before.items[1], "Batch move changed an unselected object")
                try require(editor.board == result && editor.selectedIDs == [fixtureID(1), fixtureID(3)], "Committed movement lost selection or returned different editor state")
                try require(before.revision == 0 && before.items[0].frame.x == 10, "The supplied source value was mutated")
            },
            EditorCheck("batch forms reject changed selection with an unchanged document stamp") {
                let editor = try selectedEditor()
                let before = editor.board
                editor.moveSelection()
                guard let context = editor.selectionEditor else { throw EditorCheckFailure(description: "Move Selection did not create its real context") }
                try require(context.ids == [fixtureID(1), fixtureID(3)] && context.bounds == editor.selectedBounds, "Move context did not freeze ordered members and aggregate bounds")
                try editor.setGestureSelection([fixtureID(2), fixtureID(3)])
                try require(editor.stamp == context.stamp, "The fixture unexpectedly changed the document stamp")
                let edits: [BoardEdit] = [
                    .move(ids: context.ids, offset: BoardPoint(x: 5, y: 5)),
                    .deleteMany(context.ids),
                    .duplicateMany(ids: context.ids, newIDs: [fixtureID(10), fixtureID(30)], offset: BoardPoint(x: 5, y: 5)),
                    .bringToFrontMany(context.ids), .sendToBackMany(context.ids)
                ]
                for edit in edits {
                    try requireThrows("A queued batch command used a changed selection") {
                        _ = try editor.perform(edit, stamp: context.stamp, source: before)
                    }
                    try require(editor.board == before && editor.selectedIDs == [fixtureID(2), fixtureID(3)], "Rejected batch command mutated the current board or selection")
                }
            },
            EditorCheck("batch duplication selects fresh copies in original z-order") {
                let editor = try selectedEditor()
                let before = editor.board
                let result = try editor.perform(.duplicateMany(ids: [fixtureID(3), fixtureID(1)], newIDs: [fixtureID(30), fixtureID(10)], offset: BoardPoint(x: 24, y: 24)), stamp: editor.stamp, source: before)
                try require(result.items.map(\.id) == [fixtureID(1), fixtureID(2), fixtureID(3), fixtureID(10), fixtureID(30)], "Copies followed caller selection order or displaced originals")
                try require(editor.selectedItems.map(\.id) == [fixtureID(10), fixtureID(30)], "Duplication did not select its new copies in board order")
                try require(Array(result.items.prefix(3)) == before.items, "Duplication changed original objects")
                try require(result.items[3].frame.x == 34 && result.items[4].frame.x == 144 && result.revision == 1, "Duplicate offset or transaction revision is wrong")
            },
            EditorCheck("batch deletion clears its selected cohort and keeps unrelated objects") {
                let editor = try selectedEditor()
                let before = editor.board
                let result = try editor.perform(.deleteMany([fixtureID(3), fixtureID(1)]), stamp: editor.stamp, source: before)
                try require(result.items == [before.items[1]], "Batch deletion removed an unselected object")
                try require(editor.selectedIDs.isEmpty && editor.selectedItem == nil, "Deleted IDs remained selected")
                try require(result.revision == 1, "Batch deletion did not commit as one edit")
            },
            EditorCheck("batch arrangement preserves selected identity and relative order") {
                let editor = try selectedEditor()
                let front = try editor.perform(.bringToFrontMany([fixtureID(3), fixtureID(1)]), stamp: editor.stamp, source: editor.board)
                try require(front.items.map(\.id) == [fixtureID(2), fixtureID(1), fixtureID(3)], "Bring to Front reversed the selected cohort")
                try require(editor.selectedIDs == [fixtureID(1), fixtureID(3)], "Arrangement lost the selected IDs")
                let back = try editor.perform(.sendToBackMany([fixtureID(3), fixtureID(1)]), stamp: editor.stamp, source: editor.board)
                try require(back.items.map(\.id) == [fixtureID(1), fixtureID(3), fixtureID(2)], "Send to Back reversed a cohort")
                try require(back.revision == 2 && editor.selectedItems.map(\.id) == [fixtureID(1), fixtureID(3)], "Arrangement did not preserve the current selected cohort")
            },
            EditorCheck("external board changes clear selection and cancel captured drafts") {
                let editor = try selectedEditor()
                let oldStamp = editor.stamp
                try installDraft(editor, hitID: fixtureID(1), dragged: true, offset: BoardPoint(x: 5, y: 5))
                var incoming = editor.board
                incoming.items[0].frame.x += 5
                incoming.revision += 1
                editor.receive(incoming)
                try require(editor.board == incoming && editor.selectedIDs.isEmpty, "Receiving an external board retained prior selection")
                try require(editor.gesture == nil && editor.gestureBlocked, "External change did not revoke the active draft")
                try require(editor.stamp != oldStamp, "External change did not update the transient document stamp")
                try requireThrows("An external change accepted an old editor stamp") {
                    _ = try editor.perform(.rename("Late rename"), stamp: oldStamp, source: incoming)
                }
                try require(editor.board == incoming, "A stale action mutated the received board")
            },
            EditorCheck("history notification invalidates drafts even at the same saved revision") {
                let editor = try selectedEditor()
                let board = editor.board
                let oldStamp = editor.stamp
                try installDraft(editor, hitID: fixtureID(1), dragged: true, offset: BoardPoint(x: 8, y: 8))
                editor.historyDidChange()
                try require(editor.board == board && editor.board.revision == oldStamp.revision, "History notification replayed an edit into the document")
                try require(editor.stamp.generation != oldStamp.generation && editor.selectedIDs.isEmpty && editor.gesture == nil, "History notification did not invalidate selection and draft ownership")
                try requireThrows("A same-revision history change accepted an old stamp") {
                    _ = try editor.perform(.rename("Stale rename"), stamp: oldStamp, source: board)
                }
            },
            EditorCheck("a multi-selection tap removes only the tapped member") {
                let editor = try selectedEditor()
                let before = editor.board
                try installDraft(editor, hitID: fixtureID(1))
                try require(editor.finishGesture(isEditable: true) == nil, "A selection tap emitted a persistent edit")
                try require(editor.selectedIDs == [fixtureID(3)], "A selected-member tap cleared or retained the wrong members")
                try require(editor.board == before && !editor.gestureInProgress && !editor.gestureBlocked, "Tap completion changed the board or left interaction state active")
            },
            EditorCheck("tap selection can add a member and clear on empty space") {
                let editor = try selectedEditor([fixtureID(1)])
                let before = editor.board
                let prior: Set<UUID> = [fixtureID(1)]
                try editor.setGestureSelection([fixtureID(1), fixtureID(2)])
                try installDraft(editor, hitID: fixtureID(2), before: prior)
                try require(editor.finishGesture(isEditable: true) == nil && editor.selectedIDs == [fixtureID(1), fixtureID(2)], "A new-member tap did not add exactly that member")
                try installDraft(editor, hitID: nil)
                try require(editor.finishGesture(isEditable: true) == nil && editor.selectedIDs.isEmpty, "An empty-space tap did not clear selection")
                try require(editor.board == before, "Selection-only taps changed persistent content")
            },
            EditorCheck("a latched drag returning to origin preserves selection without an edit") {
                let editor = try selectedEditor()
                let before = editor.board
                try installDraft(editor, hitID: fixtureID(1), dragged: true)
                try require(editor.finishGesture(isEditable: true) == nil, "A zero-offset completed drag emitted an edit")
                try require(editor.selectedIDs == [fixtureID(1), fixtureID(3)], "A returning drag was treated as a membership-removing tap")
                try require(editor.board == before, "Returning to the original position consumed persistent state")
            },
            EditorCheck("completed group drag returns one move and waits for explicit commit") {
                let editor = try selectedEditor()
                let before = editor.board
                let stamp = editor.stamp
                let offset = BoardPoint(x: 12, y: 8)
                try installDraft(editor, hitID: fixtureID(1), dragged: true, offset: offset)
                guard let (edit, captured) = editor.finishGesture(isEditable: true) else { throw EditorCheckFailure(description: "A valid completed group drag produced no command") }
                try require(edit == .move(ids: [fixtureID(1), fixtureID(3)], offset: offset) && captured == stamp, "Completed drag returned the wrong cohort, offset or stamp")
                try require(editor.board == before, "Draft completion wrote content before explicit commit")
                let result = try editor.perform(edit, stamp: captured, source: before)
                try require(result.revision == 1 && result.items[0].frame.x == 22 && result.items[2].frame.x == 132, "Explicit drag commit did not move the complete cohort once")
                try require(editor.finishGesture(isEditable: true) == nil, "Finishing the same interaction twice produced a second edit")
            },
            EditorCheck("read-only and invalidated movement drafts cannot commit") {
                let readOnly = try selectedEditor()
                let board = readOnly.board
                try installDraft(readOnly, hitID: fixtureID(1), dragged: true, offset: BoardPoint(x: 20, y: 20))
                try require(readOnly.finishGesture(isEditable: false) == nil && readOnly.board == board, "Read-only movement produced a persistent edit")
                try installDraft(readOnly, hitID: fixtureID(1))
                try require(readOnly.finishGesture(isEditable: false) == nil && readOnly.selectedIDs == [fixtureID(3)], "Read-only selection was incorrectly disabled")

                let changed = try selectedEditor()
                try installDraft(changed, hitID: fixtureID(1), dragged: true, offset: BoardPoint(x: 20, y: 20))
                try changed.setGestureSelection([fixtureID(2)])
                try require(changed.finishGesture(isEditable: true) == nil && changed.board == board, "A changed membership accepted an old movement draft")

                let invalidators: [(String, @MainActor (EditorState) -> Void)] = [
                    ("tool", { $0.choose(.pen) }),
                    ("mode", { $0.setMultipleSelection(false) }),
                    ("zoom", { $0.zoom(by: 1.25) }),
                    ("fit", { $0.fit() }),
                    ("reset view", { $0.resetView() }),
                    ("list selection", { $0.selectFromList(fixtureID(2)) })
                ]
                for (name, invalidate) in invalidators {
                    let editor = try selectedEditor()
                    editor.canvasSize = CGSize(width: 800, height: 600)
                    try installDraft(editor, hitID: fixtureID(1), dragged: true, offset: BoardPoint(x: 20, y: 20))
                    invalidate(editor)
                    try require(editor.gesture == nil && editor.gestureBlocked, "Changing \(name) did not revoke the draft")
                    try require(editor.finishGesture(isEditable: true) == nil && editor.board == board, "Changing \(name) allowed an old drag to commit")
                }
            }
        ]

        guard checks.count == 16, Set(checks.map(\.name)).count == 16 else {
            FileHandle.standardError.write(Data("The authored editor case set is incomplete or duplicated.\n".utf8))
            exit(1)
        }
        let results = checks.map { check -> EditorCheckResult in
            do {
                try check.run()
                return EditorCheckResult(name: check.name, status: "passed", failure: nil)
            } catch {
                return EditorCheckResult(name: check.name, status: "failed", failure: String(describing: error))
            }
        }
        let passed = results.filter { $0.status == "passed" }.count
        let report = EditorCheckReport(schemaVersion: 1, kind: "spatial-whiteboard.editor-multi-selection",
                                       status: passed == checks.count ? "passed" : "failed", expectedCases: 16,
                                       passed: passed, failed: checks.count - passed, cases: results,
                                       limits: [
                                        "Actual editor/core source state only; no window or app scene is launched.",
                                        "Captured draft completion does not prove physical DragGesture delivery or the four-screen-point threshold.",
                                        "Native UndoManager/FileDocument save behavior, renderer output, visionOS accessibility and device input are not executed."
                                       ])
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let bytes = try encoder.encode(report)
            print(String(decoding: bytes, as: UTF8.self))
        } catch {
            FileHandle.standardError.write(Data("Could not encode the editor check report: \(error)\n".utf8))
            exit(1)
        }
        exit(passed == checks.count ? 0 : 1)
    }
}
