import Foundation
import XCTest
import BoardCore

final class BoardGeometrySVGTests: XCTestCase {
    func testReverseDragNormalizesShapeFrame() throws {
        let item = try BoardGeometry.shape(kind: .rectangle, from: .init(x: 200, y: 150), to: .init(x: 20, y: 30))
        XCTAssertEqual(item.frame, BoardRect(x: 20, y: 30, width: 180, height: 120))
        XCTAssertTrue(item.points.isEmpty)
    }

    func testReverseArrowRetainsEndpointDirection() throws {
        let item = try BoardGeometry.shape(kind: .arrow, from: .init(x: 100, y: 80), to: .init(x: 10, y: 20))
        XCTAssertEqual(item.frame, BoardRect(x: 10, y: 20, width: 90, height: 60))
        XCTAssertEqual(item.points, [.init(x: 1, y: 1), .init()])
        let svg = String(decoding: try BoardSVG.encode(Board(items: [item])), as: UTF8.self)
        XCTAssertTrue(svg.contains("100.0,80.0 10.0,20.0"))
    }

    func testShapeMinimumSizesAndTextFrame() throws {
        for kind in [BoardKind.rectangle, .ellipse, .arrow] {
            let item = try BoardGeometry.shape(kind: kind, from: .init(), to: .init())
            XCTAssertEqual(item.frame, BoardRect())
        }
        let text = try BoardGeometry.shape(kind: .text, from: .init(x: -10, y: -20), to: .init(x: -10, y: -20), text: "A")
        XCTAssertEqual(text.frame, BoardRect(x: -10, y: -20, width: 160, height: 80))
    }

    func testStrokeNormalizesWorldPointsAndSupportsHorizontalOrDotStrokes() throws {
        let item = try BoardGeometry.stroke(worldPoints: [.init(x: -10, y: 50), .init(x: 10, y: 50), .init(x: 30, y: 50)])
        XCTAssertEqual(item.frame, BoardRect(x: -10, y: 50, width: 40, height: 1))
        XCTAssertEqual(item.points, [.init(), .init(x: 0.5), .init(x: 1)])
        let dot = try BoardGeometry.stroke(worldPoints: [.init(x: 3, y: 4), .init(x: 3, y: 4)])
        XCTAssertTrue(try BoardGeometry.hitTest(dot, at: .init(x: 3, y: 4), tolerance: 0))
    }

    func testGeometryRejectsInvalidInputsInsteadOfClamping() throws {
        XCTAssertThrowsError(try BoardGeometry.shape(kind: .stroke, from: .init(), to: .init()))
        XCTAssertThrowsError(try BoardGeometry.shape(kind: .rectangle, from: .init(x: .nan), to: .init()))
        XCTAssertThrowsError(try BoardGeometry.shape(kind: .text, from: .init(x: 100_000), to: .init(x: 100_000)))
        XCTAssertThrowsError(try BoardGeometry.stroke(worldPoints: [.init()]))
        XCTAssertThrowsError(try BoardGeometry.stroke(worldPoints: [.init(), .init(y: 100_001)]))
    }

    func testLineHitTestingUsesSegmentProximityInsteadOfBoundingBox() throws {
        let arrow = try BoardGeometry.shape(kind: .arrow, from: .init(), to: .init(x: 100, y: 100))
        XCTAssertTrue(try BoardGeometry.hitTest(arrow, at: .init(x: 50, y: 50), tolerance: 0))
        XCTAssertFalse(try BoardGeometry.hitTest(arrow, at: .init(x: 10, y: 90), tolerance: 2))
        XCTAssertFalse(try BoardGeometry.hitTest(arrow, at: .init(x: -10, y: -10), tolerance: 0))
        XCTAssertTrue(try BoardGeometry.hitTest(arrow, at: .init(x: -1, y: -1), tolerance: 1))
    }

    func testArrowHeadWingsAreSelectableAndShareRenderingGeometry() throws {
        let arrow = try BoardGeometry.shape(kind: .arrow, from: .init(), to: .init(x: 100, y: 0))
        let wings = try BoardGeometry.arrowWings(from: .init(), to: .init(x: 100, y: 0), width: 3)
        XCTAssertEqual(wings, [.init(x: 84, y: 8), .init(x: 84, y: -8)])
        XCTAssertTrue(try BoardGeometry.hitTest(arrow, at: wings[0], tolerance: 0))
        XCTAssertThrowsError(try BoardGeometry.arrowWings(from: .init(x: .nan), to: .init(), width: 3))
        XCTAssertThrowsError(try BoardGeometry.arrowWings(from: .init(), to: .init(x: 100), width: .infinity))
    }

    func testRectangleTextAndEllipseHitTesting() throws {
        let rect = BoardFixtures.rectangle()
        XCTAssertTrue(try BoardGeometry.hitTest(rect, at: .init(x: 50, y: 50), tolerance: 0))
        XCTAssertTrue(try BoardGeometry.hitTest(rect, at: .init(x: 9, y: 20), tolerance: 1))
        XCTAssertFalse(try BoardGeometry.hitTest(rect, at: .init(x: 8, y: 20), tolerance: 1))
        var ellipse = rect
        ellipse.kind = .ellipse
        XCTAssertTrue(try BoardGeometry.hitTest(ellipse, at: ellipse.frame.center, tolerance: 0))
        XCTAssertFalse(try BoardGeometry.hitTest(ellipse, at: .init(x: 10, y: 20), tolerance: 0))
        XCTAssertTrue(try BoardGeometry.hitTest(BoardFixtures.text(), at: .init(x: 100, y: 50), tolerance: 0))
    }

    func testHitTestingRejectsNonfiniteOrNegativeToleranceAndPoints() throws {
        let item = BoardFixtures.rectangle()
        for tolerance in [-1.0, .nan, .infinity] {
            XCTAssertThrowsError(try BoardGeometry.hitTest(item, at: .init(), tolerance: tolerance))
        }
        XCTAssertThrowsError(try BoardGeometry.hitTest(item, at: .init(x: .infinity), tolerance: 0))
        XCTAssertTrue(try BoardGeometry.hitTest(item, at: .init(), tolerance: .greatestFiniteMagnitude))
    }

    func testBoundsUnionIsOptionalAndRejectsInvalidObjects() throws {
        XCTAssertNil(try BoardGeometry.bounds(of: []))
        let a = BoardItem(frame: .init(x: -30, y: 10, width: 20, height: 30))
        let b = BoardItem(frame: .init(x: 50, y: -20, width: 40, height: 60))
        XCTAssertEqual(try BoardGeometry.bounds(of: [a, b]), .init(x: -30, y: -20, width: 120, height: 60))
        XCTAssertThrowsError(try BoardGeometry.bounds(of: [BoardItem(frame: .init(width: -1))]))
    }

    func testStandaloneSVGContainsEveryKindAndStablePalette() throws {
        var items = [BoardFixtures.rectangle(), BoardFixtures.text(2), BoardFixtures.stroke(3)]
        items.append(try BoardGeometry.shape(id: BoardFixtures.id(4), kind: .ellipse, from: .init(), to: .init(x: 20, y: 30)))
        items.append(try BoardGeometry.shape(id: BoardFixtures.id(5), kind: .arrow, from: .init(), to: .init(x: 20, y: 30)))
        for index in items.indices { items[index].style.ink = BoardInk.allCases[index] }
        items[0].style.fill = true
        let svg = String(decoding: try BoardSVG.encode(Board(items: items)), as: UTF8.self)
        for fragment in ["xmlns=\"http://www.w3.org/2000/svg\"", "<rect", "<ellipse", "<text", "<polyline", "fill-opacity=\"0.15\""] {
            XCTAssertTrue(svg.contains(fragment), fragment)
        }
        for ink in BoardInk.allCases { XCTAssertTrue(svg.contains(ink.svgColor)) }
        XCTAssertFalse(svg.contains("<script"))
        XCTAssertFalse(svg.contains("href="))
    }

    func testSVGTitleAndTextCannotInjectMarkupOrExternalReferences() throws {
        let board = Board(title: "<script>&\"'", items: [BoardFixtures.text(content: "</text><script src=\"https://bad.invalid\">& ' 😀")])
        let svg = String(decoding: try BoardSVG.encode(board), as: UTF8.self)
        XCTAssertTrue(svg.contains("&lt;script&gt;&amp;&quot;&apos;"))
        XCTAssertTrue(svg.contains("&lt;/text&gt;&lt;script src=&quot;https://bad.invalid&quot;&gt;&amp; &apos; 😀"))
        XCTAssertFalse(svg.contains("<script"))
        XCTAssertTrue(svg.contains("clip-path=\"url(#text-"))
    }

    func testSVGNewlinesAreExplicitClippedLinesAndEmptyBoardHasViewBox() throws {
        let svg = String(decoding: try BoardSVG.encode(Board(items: [BoardFixtures.text(content: "One\r\nTwo\rThree")])), as: UTF8.self)
        XCTAssertEqual(svg.components(separatedBy: "<tspan").count - 1, 3)
        XCTAssertTrue(svg.contains("dy=\"30.0\""))
        XCTAssertTrue(svg.contains("<clipPath"))
        let empty = String(decoding: try BoardSVG.encode(Board()), as: UTF8.self)
        XCTAssertTrue(empty.contains("viewBox=\"0 0 1024.0 768.0\""))
    }

    func testSVGViewBoxIncludesArrowAndStrokePadding() throws {
        let arrow = try BoardGeometry.shape(kind: .arrow, from: .init(x: -100, y: -50), to: .init(x: 100, y: 50), style: .init(strokeWidth: 12))
        let svg = String(decoding: try BoardSVG.encode(Board(items: [arrow])), as: UTF8.self)
        XCTAssertTrue(svg.contains("viewBox=\"-140.0 -90.0 280.0 180.0\""))
        XCTAssertFalse(svg.contains("nan"))
        XCTAssertFalse(svg.contains("inf"))
    }

    func testSVGRejectsInvalidStateWithoutProducingPartialExport() throws {
        XCTAssertThrowsError(try BoardSVG.encode(Board(items: [BoardItem(style: .init(strokeWidth: .nan))])))
        XCTAssertThrowsError(try BoardSVG.encode(Board(items: [BoardFixtures.rectangle(), BoardFixtures.rectangle()])))
    }
}
