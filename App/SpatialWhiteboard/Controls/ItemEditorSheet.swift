import SwiftUI
import BoardCore

@MainActor
struct ItemEditorSheet: View {
    let context: ItemEditorContext
    let isEditable: Bool
    let onApply: (BoardEdit, EditStamp) -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var x: String
    @State private var y: String
    @State private var width: String
    @State private var height: String
    @State private var text: String
    @State private var style: BoardStyle
    @State private var message: String?

    init(context: ItemEditorContext, isEditable: Bool, onApply: @escaping (BoardEdit, EditStamp) -> String?) {
        self.context = context
        self.isEditable = isEditable
        self.onApply = onApply
        _x = State(initialValue: String(context.item.frame.x))
        _y = State(initialValue: String(context.item.frame.y))
        _width = State(initialValue: String(context.item.frame.width))
        _height = State(initialValue: String(context.item.frame.height))
        _text = State(initialValue: context.item.text)
        _style = State(initialValue: context.item.style)
    }

    var body: some View {
        NavigationStack {
            Form {
                if context.item.kind == .text {
                    Section("Text") {
                        TextEditor(text: $text).frame(minHeight: 140)
                            .accessibilityLabel("Object text")
                        Text("Up to 1000 characters. Lines do not wrap; text outside the object's frame is clipped.")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Ink", selection: $style.ink) {
                            ForEach(BoardInk.allCases, id: \.self) { ink in Text(ink.title).tag(ink) }
                        }
                        Stepper("Text size \(BoardPresentation.number(style.fontSize))", value: $style.fontSize, in: 12...96, step: 2)
                    }
                }
                Section("Position and size") {
                    TextField("X", text: $x)
                    TextField("Y", text: $y)
                    TextField("Width", text: $width)
                    TextField("Height", text: $height)
                    Text("Use board units and a decimal point. Width and height must be at least 1; every edge must stay between −100000 and 100000.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message {
                    Section { Text(message).foregroundStyle(.red).accessibilityLabel("Could not apply: \(message)") }
                }
            }
            .navigationTitle(context.isNew ? "Add text" : "Edit \(context.item.kind.title.lowercased())")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply", action: apply).disabled(!isEditable) }
            }
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 560)
    }

    private func apply() {
        guard isEditable else { message = "This document is read only."; return }
        guard let x = Double(x), let y = Double(y), let width = Double(width), let height = Double(height),
              x.isFinite, y.isFinite, width.isFinite, height.isFinite else {
            message = "Enter a finite number in each position and size field."
            return
        }
        if context.item.kind == .text, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message = "Enter some text before applying."
            return
        }
        var item = context.item
        item.frame = BoardRect(x: x, y: y, width: width, height: height)
        item.text = context.item.kind == .text ? text : ""
        item.style = style
        message = onApply(context.isNew ? .add(item) : .replace(item), context.stamp)
        if message == nil { dismiss() }
    }
}
