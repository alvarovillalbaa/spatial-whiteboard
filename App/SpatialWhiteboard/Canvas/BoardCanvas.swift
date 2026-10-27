import SwiftUI
import BoardCore

@MainActor
struct BoardCanvas: View {
    let editor: EditorState
    let isEditable: Bool
    let onCommit: (BoardEdit, EditStamp) -> Void
    @GestureState private var dragActive = false

    var body: some View {
        GeometryReader { geometry in
            Group {
                if editor.tool.isDrawing && isEditable {
                    surface(size: geometry.size).handPointerBehavior(.drawing)
                } else {
                    surface(size: geometry.size)
                }
            }
            .onAppear { editor.canvasSize = geometry.size }
            .onChange(of: geometry.size) { _, size in
                editor.cancelGesture()
                editor.canvasSize = size
            }
        }
        .onDisappear { editor.endInteraction() }
        .onChange(of: dragActive) { _, active in
            guard !active, let interactionID = editor.interactionID else { return }
            // Let onEnded commit first. A canceled gesture also resets GestureState.
            Task { @MainActor in
                await Task.yield()
                guard !dragActive, editor.interactionID == interactionID else { return }
                editor.endInteraction()
            }
        }
    }

    private func surface(size: CGSize) -> some View {
        ZStack {
            Canvas { context, size in
                var drawing = context
                do {
                    try BoardRenderer.draw(board: editor.board, draft: editor.gesture, selection: editor.selectedID,
                                           viewport: editor.viewport, context: &drawing, size: size)
                } catch {
                    context.draw(Text("Could not draw this board: \(error.localizedDescription)").foregroundColor(.red),
                                 in: CGRect(x: 24, y: 24, width: max(1, size.width - 48), height: 140))
                }
            }
            .accessibilityHidden(true)
            if editor.board.items.isEmpty && editor.gesture == nil {
                VStack(spacing: 12) {
                    Image(systemName: "scribble.variable").font(.largeTitle)
                    Text("Room for your next idea").font(.title2)
                    Text("Choose a drawing tool, or add an object from the Objects panel.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(36)
                .allowsHitTesting(false)
            }
        }
        .background(.white)
        .contentShape(Rectangle())
        .clipped()
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($dragActive) { _, active, _ in active = true }
            .onChanged { value in editor.updateGesture(value, size: size, isEditable: isEditable) }
            .onEnded { value in
                editor.updateGesture(value, size: size, isEditable: isEditable)
                if let (edit, stamp) = editor.finishGesture(isEditable: isEditable) { onCommit(edit, stamp) }
            })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Whiteboard canvas")
        .accessibilityValue("\(editor.board.items.count) objects. \(editor.tool.title) tool.")
        .accessibilityHint("Use the Objects panel and inspector to select, add and edit objects without drawing gestures.")
    }
}
