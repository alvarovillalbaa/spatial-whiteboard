import Foundation
import XCTest
import BoardCore

final class BoardHistoryTests: XCTestCase {
    func testAddReplaceDeleteAndUndoRedoPreserveContentWithNewRevisions() throws {
        let item = BoardFixtures.rectangle()
        var history = try BoardHistory(board: Board(id: BoardFixtures.id(99)))
        try history.perform(.add(item), expectedRevision: 0)
        var moved = item
        moved.frame.x = 120
        try history.perform(.replace(moved), expectedRevision: 1)
        try history.perform(.delete(item.id), expectedRevision: 2)
        XCTAssertEqual(history.board.revision, 3)
        XCTAssertTrue(history.board.items.isEmpty)
        try history.undo(expectedRevision: 3)
        XCTAssertEqual(history.board.items, [moved])
        XCTAssertEqual(history.board.revision, 4)
        try history.redo(expectedRevision: 4)
        XCTAssertTrue(history.board.items.isEmpty)
        XCTAssertEqual(history.board.revision, 5)
    }

    func testDuplicatePreservesPayloadAndOffsetsOnlyFrame() throws {
        let original = BoardFixtures.stroke()
        var history = try BoardHistory(board: Board(items: [original]))
        try history.perform(.duplicate(id: original.id, newID: BoardFixtures.id(2), offset: .init(x: -20, y: 30)), expectedRevision: 0)
        let duplicate = history.board.items[1]
        XCTAssertEqual(duplicate.id, BoardFixtures.id(2))
        XCTAssertEqual(duplicate.frame.x, original.frame.x - 20)
        XCTAssertEqual(duplicate.frame.y, original.frame.y + 30)
        XCTAssertEqual(duplicate.points, original.points)
        XCTAssertEqual(duplicate.style, original.style)
        XCTAssertEqual(history.board.items[0], original)
    }

    func testFrontAndBackRespectObjectOrder() throws {
        let items = (1...3).map { BoardFixtures.rectangle($0) }
        var history = try BoardHistory(board: Board(items: items))
        try history.perform(.bringToFront(items[0].id), expectedRevision: 0)
        XCTAssertEqual(history.board.items.map(\.id), [items[1].id, items[2].id, items[0].id])
        try history.perform(.sendToBack(items[2].id), expectedRevision: 1)
        XCTAssertEqual(history.board.items.map(\.id), [items[2].id, items[1].id, items[0].id])
    }

    func testStalePerformUndoAndRedoAreAtomic() throws {
        var history = try BoardHistory()
        try history.perform(.rename("First"), expectedRevision: 0)
        let before = history.board
        XCTAssertThrowsError(try history.perform(.rename("Stale"), expectedRevision: 0)) { XCTAssertEqual($0 as? BoardError, .staleRevision) }
        XCTAssertThrowsError(try history.undo(expectedRevision: 0))
        XCTAssertThrowsError(try history.redo(expectedRevision: 0))
        XCTAssertEqual(history.board, before)
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testInvalidEditDoesNotMutateBoardOrDiscardRedo() throws {
        var history = try BoardHistory(board: Board(items: [BoardFixtures.rectangle()]))
        try history.perform(.rename("First"), expectedRevision: 0)
        try history.undo(expectedRevision: 1)
        let before = history.board
        var invalid = before.items[0]
        invalid.frame.width = -1
        XCTAssertThrowsError(try history.perform(.replace(invalid), expectedRevision: 2))
        XCTAssertEqual(history.board, before)
        XCTAssertTrue(history.canRedo)
        try history.redo(expectedRevision: 2)
        XCTAssertEqual(history.board.title, "First")
    }

    func testNoOpEditsPreserveRevisionAndHistory() throws {
        let item = BoardFixtures.rectangle()
        var history = try BoardHistory(board: Board(items: [item]))
        try history.perform(.rename("First"), expectedRevision: 0)
        try history.undo(expectedRevision: 1)
        let before = history.board
        for edit in [BoardEdit.rename(before.title), .replace(item), .bringToFront(item.id), .sendToBack(item.id)] {
            try history.perform(edit, expectedRevision: 2)
            XCTAssertEqual(history.board, before)
            XCTAssertTrue(history.canRedo)
            XCTAssertFalse(history.canUndo)
        }
    }

    func testNewEditAfterUndoDiscardsOnlyRedoBranch() throws {
        var history = try BoardHistory()
        try history.perform(.rename("A"), expectedRevision: 0)
        try history.perform(.rename("B"), expectedRevision: 1)
        try history.undo(expectedRevision: 2)
        try history.perform(.rename("C"), expectedRevision: 3)
        XCTAssertFalse(history.canRedo)
        try history.undo(expectedRevision: 4)
        XCTAssertEqual(history.board.title, "A")
    }

    func testHistoryRetainsTwentyStatesAcrossBothStacks() throws {
        var history = try BoardHistory()
        for value in 1...25 { try history.perform(.rename("Board \(value)"), expectedRevision: history.board.revision) }
        for _ in 1...20 { try history.undo(expectedRevision: history.board.revision) }
        XCTAssertEqual(history.board.title, "Board 5")
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)
        XCTAssertThrowsError(try history.undo(expectedRevision: history.board.revision))
        for _ in 1...20 { try history.redo(expectedRevision: history.board.revision) }
        XCTAssertEqual(history.board.title, "Board 25")
        XCTAssertEqual(history.board.revision, 65)
        XCTAssertFalse(history.canRedo)
    }

    func testMissingIDsAndDuplicateIDsFailTransactionally() throws {
        let item = BoardFixtures.rectangle()
        var history = try BoardHistory(board: Board(items: [item]))
        let before = history.board
        let missing = BoardFixtures.id(2)
        for edit in [BoardEdit.delete(missing), .replace(BoardFixtures.rectangle(2)), .bringToFront(missing),
                     .sendToBack(missing), .add(item), .duplicate(id: item.id, newID: item.id, offset: .init())] {
            XCTAssertThrowsError(try history.perform(edit, expectedRevision: 0))
            XCTAssertEqual(history.board, before)
            XCTAssertFalse(history.canUndo)
        }
    }

    func testInvalidDuplicateOffsetCannotMoveObjectsOutOfBounds() throws {
        var history = try BoardHistory(board: Board(items: [BoardFixtures.rectangle()]))
        let before = history.board
        for offset in [BoardPoint(x: .nan), BoardPoint(x: 100_000), BoardPoint(y: -.infinity)] {
            XCTAssertThrowsError(try history.perform(.duplicate(id: before.items[0].id, newID: BoardFixtures.id(2), offset: offset), expectedRevision: 0))
            XCTAssertEqual(history.board, before)
        }
    }

    func testRevisionOverflowPreservesBoardAndStacksWhileNoOpSucceeds() throws {
        var history = try BoardHistory(board: Board(revision: Int.max - 1))
        try history.perform(.rename("Last"), expectedRevision: Int.max - 1)
        let before = history.board
        XCTAssertThrowsError(try history.perform(.rename("Overflow"), expectedRevision: Int.max)) { XCTAssertEqual($0 as? BoardError, .revisionOverflow) }
        XCTAssertThrowsError(try history.undo(expectedRevision: Int.max))
        XCTAssertEqual(history.board, before)
        XCTAssertTrue(history.canUndo)
        try history.perform(.rename("Last"), expectedRevision: Int.max)
        XCTAssertEqual(history.board, before)
    }

    func testEmptyHistoryAndInvalidInitializationThrow() throws {
        var history = try BoardHistory()
        XCTAssertThrowsError(try history.undo(expectedRevision: 0)) { XCTAssertEqual($0 as? BoardError, .historyUnavailable) }
        XCTAssertThrowsError(try history.redo(expectedRevision: 0))
        XCTAssertThrowsError(try BoardHistory(board: Board(revision: -1)))
        let content = String(repeating: "👩‍👩‍👧‍👦", count: 400)
        XCTAssertThrowsError(try BoardHistory(board: Board(items: (1...500).map { BoardFixtures.text($0, content: content) })))
    }

    func testFinalRevisionGrowthCannotPushAnEditBeyondEncodedCap() throws {
        let board = try BoardFixtures.exactSizeBoard(revision: 9)
        XCTAssertEqual(try BoardCodec.encode(board).count, 4 * 1024 * 1024)
        var history = try BoardHistory(board: board)
        XCTAssertThrowsError(try history.perform(.rename("Changed Board!"), expectedRevision: 9))
        XCTAssertEqual(history.board, board)
        XCTAssertFalse(history.canUndo)
    }

    func testUndoAndRedoValidateRestoredContentAtItsNewRevision() throws {
        let full = try BoardFixtures.exactSizeBoard(revision: 8)
        var smaller = full
        let last = smaller.items.removeLast()
        smaller.revision = 7
        var history = try BoardHistory(board: smaller)
        try history.perform(.add(last), expectedRevision: 7)
        XCTAssertEqual(history.board, full)
        try history.undo(expectedRevision: 8)
        let beforeRedo = history.board
        XCTAssertThrowsError(try history.redo(expectedRevision: 9))
        XCTAssertEqual(history.board, beforeRedo)
        XCTAssertTrue(history.canRedo)

        var other = try BoardHistory(board: try BoardFixtures.exactSizeBoard(revision: 9))
        try other.perform(.delete(last.id), expectedRevision: 9)
        let beforeUndo = other.board
        XCTAssertThrowsError(try other.undo(expectedRevision: 10))
        XCTAssertEqual(other.board, beforeUndo)
        XCTAssertTrue(other.canUndo)
    }
}
