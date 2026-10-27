import Foundation
import BoardCore

enum EditorTool: String, CaseIterable, Identifiable {
    case select, pan, pen, rectangle, ellipse, arrow, text

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .pan: return "hand.draw"
        case .pen: return "pencil.tip"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        }
    }

    var kind: BoardKind? {
        switch self {
        case .select, .pan: return nil
        case .pen: return .stroke
        case .rectangle: return .rectangle
        case .ellipse: return .ellipse
        case .arrow: return .arrow
        case .text: return .text
        }
    }

    var isDrawing: Bool { kind != nil }

    var hint: String {
        switch self {
        case .select: return "Select an object, then drag to move it. Use the inspector for exact dimensions."
        case .pan: return "Drag to move around the board. Zoom and Fit keep your work in view."
        case .pen: return "Pinch and drag to draw a stroke. Release to add it to the board."
        case .rectangle, .ellipse, .arrow: return "Drag from one corner to another. Release to add the object."
        case .text: return "Choose a place on the canvas, then enter your text."
        }
    }
}

struct EditStamp: Equatable {
    let boardID: UUID
    let revision: Int
    let generation: UUID
}

struct EditorIssue: Identifiable {
    let id = UUID()
    let message: String
}

struct ItemEditorContext: Identifiable {
    let id = UUID()
    let item: BoardItem
    let isNew: Bool
    let stamp: EditStamp
}

struct BoardTitleContext: Identifiable {
    let id = UUID()
    let title: String
    let stamp: EditStamp
}
