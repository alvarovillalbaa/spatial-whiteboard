import Foundation
import XCTest
import BoardCore

final class BoardCodecTests: XCTestCase {
    func testDefaultBoardRoundTripsWithoutInventedObjects() throws {
        let board = Board(id: BoardFixtures.id(99))
        XCTAssertEqual(try BoardCodec.decode(BoardCodec.encode(board)), board)
        XCTAssertEqual(board.title, "Untitled Board")
        XCTAssertTrue(board.items.isEmpty)
        XCTAssertEqual(board.revision, 0)
    }

    func testEveryKindAndInkRoundTrips() throws {
        var items = [BoardFixtures.stroke(), BoardFixtures.rectangle(2), BoardFixtures.text(3, content: "Hello\n世界")]
        items.append(try BoardGeometry.shape(id: BoardFixtures.id(4), kind: .ellipse, from: .init(), to: .init(x: 40, y: 60)))
        items.append(try BoardGeometry.shape(id: BoardFixtures.id(5), kind: .arrow, from: .init(x: 40, y: 60), to: .init()))
        for index in items.indices { items[index].style.ink = BoardInk.allCases[index] }
        items[1].style.fill = true
        let board = Board(id: BoardFixtures.id(99), items: items)
        XCTAssertEqual(try BoardCodec.decode(BoardCodec.encode(board)), board)
    }

    func testVersionAndRevisionAreStrictAndMaximumRevisionSurvives() throws {
        for board in [Board(version: 0), Board(version: 2), Board(revision: -1)] {
            XCTAssertThrowsError(try BoardCodec.encode(board))
        }
        let board = Board(revision: Int.max)
        XCTAssertEqual(try BoardCodec.decode(BoardCodec.encode(board)), board)
    }

    func testTitleCharacterAndByteBounds() throws {
        XCTAssertNoThrow(try BoardCodec.encode(Board(title: String(repeating: "é", count: 80))))
        for title in ["", " \n\t", String(repeating: "a", count: 81), "a" + String(repeating: "\u{301}", count: 3000)] {
            XCTAssertThrowsError(try BoardCodec.encode(Board(title: title)))
        }
    }

    func testTextCharacterByteAndXMLScalarBounds() throws {
        XCTAssertNoThrow(try BoardCodec.encode(Board(items: [BoardFixtures.text(content: String(repeating: "é", count: 1000))])))
        for text in [String(repeating: "a", count: 1001), "a" + String(repeating: "\u{301}", count: 33_000), "unsafe\u{0}", "unsafe\u{B}"] {
            XCTAssertThrowsError(try BoardCodec.encode(Board(items: [BoardFixtures.text(content: text)])))
        }
        XCTAssertNoThrow(try BoardCodec.encode(Board(items: [BoardFixtures.text(content: "\t\r\n<>&\"'😀")])))
    }

    func testFrameCoordinateAndDimensionBounds() throws {
        let valid = BoardItem(frame: .init(x: -100_000, y: -100_000, width: 200_000, height: 200_000))
        XCTAssertNoThrow(try BoardCodec.encode(Board(items: [valid])))
        let frames = [BoardRect(width: 0), BoardRect(height: -1), BoardRect(width: 200_001),
                      BoardRect(x: 100_000), BoardRect(y: -100_001), BoardRect(x: .nan), BoardRect(height: .infinity)]
        for frame in frames { XCTAssertThrowsError(try BoardCodec.encode(Board(items: [BoardItem(frame: frame)]))) }
    }

    func testStyleNumbersAreFiniteAndBounded() throws {
        let styles = [BoardStyle(strokeWidth: 0), BoardStyle(strokeWidth: 13), BoardStyle(strokeWidth: .nan),
                      BoardStyle(fontSize: 11), BoardStyle(fontSize: 97), BoardStyle(fontSize: .infinity)]
        for style in styles { XCTAssertThrowsError(try BoardCodec.encode(Board(items: [BoardItem(style: style)]))) }
        XCTAssertNoThrow(try BoardCodec.encode(Board(items: [BoardItem(style: .init(strokeWidth: 1, fontSize: 12)), BoardItem(style: .init(strokeWidth: 12, fontSize: 96))])))
    }

    func testKindPayloadsCannotBeMixed() throws {
        var invalid = [BoardFixtures.rectangle(), BoardFixtures.rectangle(2), BoardFixtures.text(3), BoardFixtures.stroke(4)]
        invalid[0].points = [.init(), .init(x: 1, y: 1)]
        invalid[1].text = "Hidden text"
        invalid[2].points = [.init()]
        invalid[3].text = "Hidden text"
        invalid.append(BoardItem(kind: .arrow, points: [.init()]))
        invalid.append(BoardItem(kind: .stroke, points: [.init()]))
        for item in invalid { XCTAssertThrowsError(try BoardCodec.encode(Board(items: [item]))) }
    }

    func testPointNormalizationAndPerStrokeLimit() throws {
        XCTAssertNoThrow(try BoardCodec.encode(Board(items: [BoardFixtures.stroke(count: 10_000)])))
        XCTAssertThrowsError(try BoardCodec.encode(Board(items: [BoardFixtures.stroke(count: 10_001)])))
        for point in [BoardPoint(x: -0.01), BoardPoint(y: 1.01), BoardPoint(x: .nan), BoardPoint(y: .infinity)] {
            var stroke = BoardFixtures.stroke()
            stroke.points[0] = point
            XCTAssertThrowsError(try BoardCodec.encode(Board(items: [stroke])))
        }
    }

    func testBoardItemAndTotalPointLimits() throws {
        XCTAssertNoThrow(try BoardCodec.encode(Board(items: (1...500).map { BoardFixtures.rectangle($0) })))
        XCTAssertThrowsError(try BoardCodec.encode(Board(items: (1...501).map { BoardFixtures.rectangle($0) })))
        let strokes = (1...5).map { BoardFixtures.stroke($0, count: 10_000) }
        XCTAssertNoThrow(try BoardCodec.encode(Board(items: strokes)))
        XCTAssertThrowsError(try BoardCodec.encode(Board(items: strokes + [BoardFixtures.stroke(6)])))
    }

    func testDuplicateObjectIDsRejectTheWholeDocument() throws {
        XCTAssertThrowsError(try BoardCodec.encode(Board(items: [BoardFixtures.rectangle(), BoardFixtures.text()])))
        var object = try BoardFixtures.object(Board(items: [BoardFixtures.rectangle()]))
        let items = object["items"] as! [Any]
        object["items"] = items + items
        XCTAssertThrowsError(try BoardCodec.decode(BoardFixtures.data(object)))
    }

    func testUnknownFieldsAtEveryRecordDepthAreRejected() throws {
        let original = try BoardFixtures.object(Board(items: [BoardFixtures.stroke()]))
        var root = original
        root["remoteURL"] = "https://example.invalid"
        XCTAssertThrowsError(try BoardCodec.decode(BoardFixtures.data(root)))
        for location in ["item", "frame", "style", "point"] {
            var object = original
            var items = object["items"] as! [[String: Any]]
            if location == "item" { items[0]["unknown"] = true }
            else if location == "point" {
                var points = items[0]["points"] as! [[String: Any]]
                points[0]["unknown"] = true
                items[0]["points"] = points
            } else {
                var nested = items[0][location] as! [String: Any]
                nested["unknown"] = true
                items[0][location] = nested
            }
            object["items"] = items
            XCTAssertThrowsError(try BoardCodec.decode(BoardFixtures.data(object)), location)
        }
    }

    func testDuplicateRootFieldsCannotHideData() throws {
        let encoded = String(decoding: try BoardCodec.encode(Board(items: [BoardFixtures.rectangle()])), as: UTF8.self)
        let ambiguous = String(encoded.dropLast()) + ",\"items\":[]}"
        XCTAssertThrowsError(try BoardCodec.decode(Data(ambiguous.utf8)))
    }

    func testEscapedEquivalentAndNestedDuplicateKeysReject() throws {
        let encoded = String(decoding: try BoardCodec.encode(Board(items: [BoardFixtures.rectangle()])), as: UTF8.self)
        let escaped = encoded.replacingOccurrences(of: "\"title\":", with: "\"ti\\u0074le\":\"Hidden\",\"title\":")
        let nested = encoded.replacingOccurrences(of: "\"width\":", with: "\"width\":99,\"width\":")
        XCTAssertThrowsError(try BoardCodec.decode(Data(escaped.utf8)))
        XCTAssertThrowsError(try BoardCodec.decode(Data(nested.utf8)))
    }

    func testRepeatedKeysInSeparateObjectsAndQuotedTextAreValid() throws {
        let board = Board(items: [BoardFixtures.text(content: "{\"title\":\"one\",\"title\":\"two\"} \\\""), BoardFixtures.rectangle(2)])
        XCTAssertEqual(try BoardCodec.decode(BoardCodec.encode(board)), board)
    }

    func testUTF8BOMIsOptional() throws {
        let board = Board()
        let encoded = try BoardCodec.encode(board)
        XCTAssertEqual(try BoardCodec.decode(Data([0xEF, 0xBB, 0xBF]) + encoded), board)
    }

    func testInvalidUTF8RawNULAndUTF16Or32AreRejected() throws {
        XCTAssertThrowsError(try BoardCodec.decode(Data([0xFF, 0xFE, 0x7B])))
        let text = String(decoding: try BoardCodec.encode(Board()), as: UTF8.self)
        for encoding in [String.Encoding.utf16LittleEndian, .utf16BigEndian, .utf32LittleEndian, .utf32BigEndian] {
            let encoded = try XCTUnwrap(text.data(using: encoding))
            XCTAssertThrowsError(try BoardCodec.decode(encoded))
        }
        XCTAssertThrowsError(try BoardCodec.decode(Data(text.utf8) + Data([0])))
    }

    func testInputByteLimitAcceptsExactCapAndRejectsOneMoreByte() throws {
        let board = Board()
        var data = try BoardCodec.encode(board)
        data.append(Data(repeating: 0x20, count: 4 * 1024 * 1024 - data.count))
        XCTAssertEqual(try BoardCodec.decode(data), board)
        data.append(0x20)
        XCTAssertThrowsError(try BoardCodec.decode(data))
    }

    func testEncodeRejectsCumulativeOversizeDespiteValidIndividualTexts() throws {
        let content = String(repeating: "👩‍👩‍👧‍👦", count: 400)
        let board = Board(items: (1...500).map { BoardFixtures.text($0, content: content) })
        XCTAssertThrowsError(try BoardCodec.encode(board))
    }

    func testNestingIsBoundedBeforeFoundationParsing() throws {
        let deep = String(repeating: "[", count: 17) + "0" + String(repeating: "]", count: 17)
        XCTAssertThrowsError(try BoardCodec.decode(Data(deep.utf8)))
        let quoted = Board(items: [BoardFixtures.text(content: String(repeating: "[", count: 100))])
        XCTAssertEqual(try BoardCodec.decode(BoardCodec.encode(quoted)), quoted)
    }

    func testMalformedIncompleteAndTrailingJSONReject() throws {
        for text in ["", "{", "[]", "{]", "{}{}", "{\"title\":\"unfinished", "{\"items\":[,]}"] {
            XCTAssertThrowsError(try BoardCodec.decode(Data(text.utf8)), text)
        }
    }

    func testMissingNullBooleanAndUnknownEnumValuesReject() throws {
        let original = try BoardFixtures.object(Board(items: [BoardFixtures.rectangle()]))
        for field in ["version", "id", "title", "revision", "items"] {
            var object = original
            object.removeValue(forKey: field)
            XCTAssertThrowsError(try BoardCodec.decode(BoardFixtures.data(object)))
        }
        for value: Any in [NSNull(), true, "1"] {
            var object = original
            object["revision"] = value
            XCTAssertThrowsError(try BoardCodec.decode(BoardFixtures.data(object)))
        }
        var object = original
        var items = object["items"] as! [[String: Any]]
        items[0]["kind"] = "script"
        object["items"] = items
        XCTAssertThrowsError(try BoardCodec.decode(BoardFixtures.data(object)))
    }

    func testNonfiniteJSONNumberAndInvalidDecodedStateReject() throws {
        let encoded = String(decoding: try BoardCodec.encode(Board(items: [BoardFixtures.rectangle()])), as: UTF8.self)
        XCTAssertThrowsError(try BoardCodec.decode(Data(encoded.replacingOccurrences(of: "\"width\":100", with: "\"width\":1e999").utf8)))
        XCTAssertThrowsError(try BoardCodec.decode(Data(encoded.replacingOccurrences(of: "\"width\":100", with: "\"width\":0").utf8)))
    }

    func testFailedDecodeLeavesSuppliedBytesUnchanged() throws {
        let source = Data("{\"title\":\"Original recovery bytes\",\"items\":[]}".utf8)
        let copy = source
        XCTAssertThrowsError(try BoardCodec.decode(source))
        XCTAssertEqual(source, copy)
    }
}
