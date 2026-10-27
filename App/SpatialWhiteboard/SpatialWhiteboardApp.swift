import SwiftUI

@main
struct SpatialWhiteboardApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: BoardDocument()) { file in
            BoardEditor(document: file.$document, isEditable: file.isEditable)
        }
        .defaultSize(width: 1400, height: 900)
    }
}
