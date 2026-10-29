import Foundation
import XCTest
import BoardCore

final class BoardBatchEditingTests: XCTestCase {
    func testTranslatedItemPreservesPayloadAndRejectsInvalidGeometry() throws {
        let arrow = try BoardGeometry.shape(id: BoardFixtures.id(2), kind: .arrow,
                                             from: .init(x: 90, y: 80), to: .init(x: 10, y: 20))
        for item in [BoardFixtures.stroke(), arrow, BoardFixtures.text(3, content: "A note")] {
            let moved = try BoardGeometry.translated(item, by: .init(x: 7, y: -9))
            XCTAssertEqual(moved.id, item.id)
            XCTAssertEqual(moved.kind, item.kind)
            XCTAssertEqual(moved.frame, BoardRect(x: item.frame.x + 7, y: item.frame.y - 9,
                                                 width: item.frame.width, height: item.frame.height))
            XCTAssertEqual(moved.points, item.points)
            XCTAssertEqual(moved.text, item.text)
            XCTAssertEqual(moved.style, item.style)
        }
        var invalid = BoardFixtures.rectangle()
        invalid.frame.width = 0
        XCTAssertThrowsError(try BoardGeometry.translated(invalid, by: .init()))
        invalid = BoardFixtures.stroke()
        invalid.points[0].x = 2
        XCTAssertThrowsError(try BoardGeometry.translated(invalid, by: .init()))
    }

    func testMoveSelectionPreservesRelativePositionsAndNormalizedPayload() throws {
        let untouched = BoardFixtures.rectangle()
        let stroke = BoardFixtures.stroke(2)
        let arrow = try BoardGeometry.shape(id: BoardFixtures.id(3), kind: .arrow,
                                             from: .init(x: 100, y: 80), to: .init(x: 10, y: 20))
        let text = BoardFixtures.text(4, content: "Keep this text")
        let items = [untouched, stroke, arrow, text]
        var history = try BoardHistory(board: Board(items: items))
        try history.perform(.move(ids: [text.id, arrow.id, stroke.id], offset: .init(x: 25, y: -15)), expectedRevision: 0)
        XCTAssertEqual(history.board.revision, 1)
        XCTAssertEqual(history.board.items.map(\.id), items.map(\.id))
        XCTAssertEqual(history.board.items[0], untouched)
        XCTAssertEqual(history.board.items[1].frame, BoardRect(x: 25, y: -15, width: 100, height: 100))
        XCTAssertEqual(history.board.items[2].frame, BoardRect(x: 35, y: 5, width: 90, height: 60))
        XCTAssertEqual(history.board.items[3].frame, BoardRect(x: 25, y: -15, width: 200, height: 100))
        for index in 1...3 {
            XCTAssertEqual(history.board.items[index].points, items[index].points)
            XCTAssertEqual(history.board.items[index].text, items[index].text)
            XCTAssertEqual(history.board.items[index].style, items[index].style)
        }
        let moved = history.board.items
        try history.undo(expectedRevision: 1)
        XCTAssertEqual(history.board.items, items)
        XCTAssertFalse(history.canUndo)
        try history.redo(expectedRevision: 2)
        XCTAssertEqual(history.board.items, moved)
    }

    func testMoveSupportsFiniteFullPlaneOffsets() throws {
        let item = BoardItem(id: BoardFixtures.id(1), frame: .init(x: -100_000, y: 0, width: 1, height: 1))
        var history = try BoardHistory(board: Board(items: [item]))
        try history.perform(.move(ids: [item.id], offset: .init(x: 199_999)), expectedRevision: 0)
        XCTAssertEqual(history.board.items[0].frame, BoardRect(x: 99_999, y: 0, width: 1, height: 1))
        XCTAssertEqual(history.board.revision, 1)
    }

    func testBatchTranslationFailuresPreserveTheWholeBoardAndRedo() throws {
        let first = BoardFixtures.rectangle()
        let edge = BoardItem(id: BoardFixtures.id(2), frame: .init(x: 99_990, y: 0, width: 10, height: 1))
        var history = try BoardHistory(board: Board(items: [first, edge]))
        try history.perform(.rename("A change"), expectedRevision: 0)
        try history.undo(expectedRevision: 1)
        let before = history.board
        for offset in [BoardPoint(x: 1), BoardPoint(x: .nan), BoardPoint(y: .infinity),
                       BoardPoint(x: Double.greatestFiniteMagnitude)] {
            for edit in [BoardEdit.move(ids: [first.id, edge.id], offset: offset),
                         .duplicateMany(ids: [first.id, edge.id], newIDs: [BoardFixtures.id(3), BoardFixtures.id(4)], offset: offset)] {
                XCTAssertThrowsError(try history.perform(edit, expectedRevision: 2))
                XCTAssertEqual(history.board, before)
                XCTAssertFalse(history.canUndo)
                XCTAssertTrue(history.canRedo)
            }
        }
        try history.redo(expectedRevision: 2)
        XCTAssertEqual(history.board.title, "A change")
    }

    func testBatchSelectionRejectsMissingAndRepeatedIDs() throws {
        let item = BoardFixtures.rectangle()
        var history = try BoardHistory(board: Board(items: [item]))
        let before = history.board
        for ids in [[item.id, BoardFixtures.id(2)], [item.id, item.id]] {
            for edit in [BoardEdit.move(ids: ids, offset: .init()), .deleteMany(ids),
                         .duplicateMany(ids: ids, newIDs: [BoardFixtures.id(3), BoardFixtures.id(4)], offset: .init()),
                         .bringToFrontMany(ids), .sendToBackMany(ids)] {
                XCTAssertThrowsError(try history.perform(edit, expectedRevision: 0))
                XCTAssertEqual(history.board, before)
                XCTAssertFalse(history.canUndo)
                XCTAssertFalse(history.canRedo)
            }
        }
    }

    func testDuplicateSelectionUsesExplicitMappingAndOriginalZOrder() throws {
        let first = BoardFixtures.stroke()
        let middle = BoardFixtures.rectangle(2)
        let last = BoardFixtures.text(3, content: "Selected text")
        let originals = [first, middle, last]
        var history = try BoardHistory(board: Board(items: originals))
        try history.perform(.duplicateMany(ids: [last.id, first.id],
                                           newIDs: [BoardFixtures.id(30), BoardFixtures.id(10)],
                                           offset: .init(x: -20, y: 30)), expectedRevision: 0)
        XCTAssertEqual(Array(history.board.items.prefix(3)), originals)
        XCTAssertEqual(history.board.items.map(\.id), [first.id, middle.id, last.id, BoardFixtures.id(10), BoardFixtures.id(30)])
        let firstCopy = history.board.items[3], lastCopy = history.board.items[4]
        XCTAssertEqual(firstCopy.frame, BoardRect(x: -20, y: 30, width: 100, height: 100))
        XCTAssertEqual(lastCopy.frame, BoardRect(x: -20, y: 30, width: 200, height: 100))
        XCTAssertEqual(firstCopy.points, first.points)
        XCTAssertEqual(firstCopy.style, first.style)
        XCTAssertEqual(lastCopy.text, last.text)
        XCTAssertEqual(lastCopy.style, last.style)
        XCTAssertEqual(history.board.revision, 1)
        try history.undo(expectedRevision: 1)
        XCTAssertEqual(history.board.items, originals)
        XCTAssertFalse(history.canUndo)
        try history.redo(expectedRevision: 2)
        XCTAssertEqual(history.board.items.count, 5)
    }

    func testDuplicateSelectionRejectsCardinalityAndCollidingIDs() throws {
        let items = [BoardFixtures.rectangle(), BoardFixtures.rectangle(2)]
        var history = try BoardHistory(board: Board(items: items))
        let before = history.board
        for ids in [[BoardFixtures.id(3)], [BoardFixtures.id(3), BoardFixtures.id(3)],
                    [BoardFixtures.id(3), items[0].id]] {
            XCTAssertThrowsError(try history.perform(.duplicateMany(ids: items.map(\.id), newIDs: ids, offset: .init()), expectedRevision: 0))
            XCTAssertEqual(history.board, before)
            XCTAssertFalse(history.canUndo)
        }
        XCTAssertThrowsError(try history.perform(.duplicateMany(ids: [], newIDs: [BoardFixtures.id(3)], offset: .init()), expectedRevision: 0))
        XCTAssertEqual(history.board, before)
    }

    func testDuplicateSelectionObjectLimitPreservesRedo() throws {
        let items = (1...500).map { BoardFixtures.rectangle($0) }
        var history = try BoardHistory(board: Board(items: items))
        try history.perform(.rename("A change"), expectedRevision: 0)
        try history.undo(expectedRevision: 1)
        let before = history.board
        XCTAssertThrowsError(try history.perform(.duplicateMany(ids: [items[0].id], newIDs: [BoardFixtures.id(501)], offset: .init()), expectedRevision: 2))
        XCTAssertEqual(history.board, before)
        XCTAssertTrue(history.canRedo)
        XCTAssertFalse(history.canUndo)
    }

    func testDuplicateSelectionPointLimitPreservesBoardAndHistory() throws {
        let items = (1...5).map { BoardFixtures.stroke($0, count: 10_000) }
        var history = try BoardHistory(board: Board(items: items))
        let before = history.board
        XCTAssertThrowsError(try history.perform(.duplicateMany(ids: [items[0].id], newIDs: [BoardFixtures.id(6)], offset: .init()), expectedRevision: 0))
        XCTAssertEqual(history.board, before)
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testBatchCandidateMustFitEncodedByteCap() throws {
        var board = try BoardFixtures.exactSizeBoard(revision: 0)
        board.items.removeLast()
        var history = try BoardHistory(board: board)
        let before = history.board
        XCTAssertThrowsError(try history.perform(.duplicateMany(ids: [board.items[0].id],
                                                               newIDs: [BoardFixtures.id(501)], offset: .init()), expectedRevision: 0)) {
            XCTAssertEqual($0 as? BoardError, .invalid("Board documents must be at most 4 MB."))
        }
        XCTAssertEqual(history.board, before)
        XCTAssertFalse(history.canUndo)
    }

    func testDeleteSelectionIsOneUndoableRevision() throws {
        let items = (1...4).map { BoardFixtures.rectangle($0) }
        var history = try BoardHistory(board: Board(items: items))
        try history.perform(.deleteMany([items[2].id, items[0].id]), expectedRevision: 0)
        XCTAssertEqual(history.board.items, [items[1], items[3]])
        XCTAssertEqual(history.board.revision, 1)
        try history.undo(expectedRevision: 1)
        XCTAssertEqual(history.board.items, items)
        XCTAssertFalse(history.canUndo)
        try history.redo(expectedRevision: 2)
        XCTAssertEqual(history.board.items, [items[1], items[3]])
    }

    func testFrontBackStablePartitionsBothCohorts() throws {
        let items = (1...5).map { BoardFixtures.rectangle($0) }
        var history = try BoardHistory(board: Board(items: items))
        try history.perform(.bringToFrontMany([items[2].id, items[0].id]), expectedRevision: 0)
        XCTAssertEqual(history.board.items, [items[1], items[3], items[4], items[0], items[2]])
        try history.perform(.sendToBackMany([items[2].id, items[0].id]), expectedRevision: 1)
        XCTAssertEqual(history.board.items, [items[0], items[2], items[1], items[3], items[4]])
        try history.undo(expectedRevision: 2)
        XCTAssertEqual(history.board.items, [items[1], items[3], items[4], items[0], items[2]])
    }

    func testEmptyAndAlreadyAppliedSelectionsPreserveRedoAndRevision() throws {
        let items = (1...3).map { BoardFixtures.rectangle($0) }
        var history = try BoardHistory(board: Board(items: items))
        try history.perform(.rename("A change"), expectedRevision: 0)
        try history.undo(expectedRevision: 1)
        let before = history.board
        for edit in [BoardEdit.move(ids: [], offset: .init(x: 20)), .deleteMany([]),
                     .duplicateMany(ids: [], newIDs: [], offset: .init(x: 20)),
                     .bringToFrontMany([]), .sendToBackMany([]),
                     .move(ids: [items[1].id, items[0].id], offset: .init()),
                     .bringToFrontMany([items[2].id, items[1].id]),
                     .sendToBackMany([items[1].id, items[0].id]),
                     .bringToFrontMany(items.reversed().map(\.id)), .sendToBackMany(items.map(\.id))] {
            try history.perform(edit, expectedRevision: 2)
            XCTAssertEqual(history.board, before)
            XCTAssertTrue(history.canRedo)
            XCTAssertFalse(history.canUndo)
        }
    }

    func testInvalidOffsetsRejectEvenEmptySelections() throws {
        var history = try BoardHistory()
        let before = history.board
        for offset in [BoardPoint(x: .nan), BoardPoint(y: -.infinity)] {
            XCTAssertThrowsError(try history.perform(.move(ids: [], offset: offset), expectedRevision: 0))
            XCTAssertThrowsError(try history.perform(.duplicateMany(ids: [], newIDs: [], offset: offset), expectedRevision: 0))
            XCTAssertEqual(history.board, before)
            XCTAssertFalse(history.canUndo)
        }
    }

    func testStaleBatchCommandsDoNotMutateBoardOrStacks() throws {
        let item = BoardFixtures.rectangle()
        var history = try BoardHistory(board: Board(items: [item]))
        try history.perform(.rename("Changed"), expectedRevision: 0)
        let before = history.board
        for edit in [BoardEdit.move(ids: [item.id], offset: .init(x: 20)), .deleteMany([item.id]),
                     .duplicateMany(ids: [item.id], newIDs: [BoardFixtures.id(2)], offset: .init()),
                     .bringToFrontMany([]), .sendToBackMany([]), .move(ids: [], offset: .init(x: .nan))] {
            XCTAssertThrowsError(try history.perform(edit, expectedRevision: 0)) { XCTAssertEqual($0 as? BoardError, .staleRevision) }
            XCTAssertEqual(history.board, before)
            XCTAssertTrue(history.canUndo)
            XCTAssertFalse(history.canRedo)
        }
    }

    func testRevisionOverflowIsAtomicWhileNoOpsStillSucceed() throws {
        let item = BoardFixtures.rectangle()
        var history = try BoardHistory(board: Board(revision: Int.max, items: [item]))
        let before = history.board
        for edit in [BoardEdit.move(ids: [item.id], offset: .init(x: 1)), .deleteMany([item.id]),
                     .duplicateMany(ids: [item.id], newIDs: [BoardFixtures.id(2)], offset: .init())] {
            XCTAssertThrowsError(try history.perform(edit, expectedRevision: Int.max)) { XCTAssertEqual($0 as? BoardError, .revisionOverflow) }
            XCTAssertEqual(history.board, before)
            XCTAssertFalse(history.canUndo)
            XCTAssertFalse(history.canRedo)
        }
        for edit in [BoardEdit.move(ids: [item.id], offset: .init()), .bringToFrontMany([item.id]),
                     .sendToBackMany([item.id]), .deleteMany([])] {
            try history.perform(edit, expectedRevision: Int.max)
            XCTAssertEqual(history.board, before)
        }
    }
}
