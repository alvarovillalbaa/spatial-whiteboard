import SwiftUI
import BoardCore

@MainActor
struct BoardInspector: View {
    let editor: EditorState
    let isEditable: Bool
    let onCommand: (BoardEdit, EditStamp) -> Void

    var body: some View {
        Form {
            if let item = editor.selectedItem {
                let stamp = editor.stamp
                Section(item.kind.title) {
                    LabeledContent("X", value: BoardPresentation.number(item.frame.x))
                    LabeledContent("Y", value: BoardPresentation.number(item.frame.y))
                    LabeledContent("Width", value: BoardPresentation.number(item.frame.width))
                    LabeledContent("Height", value: BoardPresentation.number(item.frame.height))
                    Button(item.kind == .text ? "Edit text and dimensions" : "Edit position and dimensions") { editor.editSelected() }
                        .disabled(!isEditable)
                }
                Section("Object style") {
                    styleControls(style: item.style, kind: item.kind) { style in
                        var replacement = item
                        replacement.style = style
                        onCommand(.replace(replacement), stamp)
                    }
                    .disabled(!isEditable)
                    Button("Use style for new objects") { editor.cancelGesture(); editor.style = item.style }
                }
                Section("Arrange") {
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        onCommand(.duplicate(id: item.id, newID: UUID(), offset: BoardPoint(x: 24, y: 24)), stamp)
                    }
                    Button("Bring to front", systemImage: "square.3.layers.3d.top.filled") { onCommand(.bringToFront(item.id), stamp) }
                    Button("Send to back", systemImage: "square.3.layers.3d.bottom.filled") { onCommand(.sendToBack(item.id), stamp) }
                    Button("Delete object", systemImage: "trash", role: .destructive) { onCommand(.delete(item.id), stamp) }
                }
                .disabled(!isEditable)
                Button("Clear selection") { editor.select(nil) }
            } else {
                Section("Drawing style") {
                    styleControls(style: editor.style, kind: editor.tool.kind) { style in
                        editor.cancelGesture()
                        editor.style = style
                    }
                    .disabled(!isEditable)
                }
                Section {
                    Text("Select an object on the canvas or in the Objects panel to edit it.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 240, idealWidth: 270, maxWidth: 300)
    }

    private func styleControls(style: BoardStyle, kind: BoardKind?, update: @escaping (BoardStyle) -> Void) -> some View {
        Group {
            Picker("Ink", selection: Binding(get: { style.ink }, set: { value in
                var candidate = style; candidate.ink = value; update(candidate)
            })) {
                ForEach(BoardInk.allCases, id: \.self) { ink in Text(ink.title).tag(ink) }
            }
            if kind == .rectangle || kind == .ellipse || kind == nil {
                Toggle("Fill shape", isOn: Binding(get: { style.fill }, set: { value in
                    var candidate = style; candidate.fill = value; update(candidate)
                }))
            }
            if kind != .text {
                Stepper("Line width \(BoardPresentation.number(style.strokeWidth))", value: Binding(get: { style.strokeWidth }, set: { value in
                    var candidate = style; candidate.strokeWidth = value; update(candidate)
                }), in: 1...12, step: 1)
            }
            if kind == .text || kind == nil {
                Stepper("Text size \(BoardPresentation.number(style.fontSize))", value: Binding(get: { style.fontSize }, set: { value in
                    var candidate = style; candidate.fontSize = value; update(candidate)
                }), in: 12...96, step: 2)
            }
        }
    }
}
