import SwiftUI
import BoardCore

@MainActor
struct ObjectList: View {
    let editor: EditorState
    let isEditable: Bool
    let onAdd: (BoardKind) -> Void
    let onCommand: (BoardEdit, EditStamp) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Objects").font(.headline)
                Spacer()
                Menu {
                    ForEach([BoardKind.rectangle, .ellipse, .arrow, .text], id: \.self) { kind in
                        Button { onAdd(kind) } label: { Label(kind.title, systemImage: kind.symbol) }
                    }
                } label: { Label("Add object", systemImage: "plus").labelStyle(.iconOnly) }
                .disabled(!isEditable)
                .accessibilityLabel("Add object")
            }
            .padding()
            if editor.board.items.isEmpty {
                Text("Add a shape here, or draw on the canvas. Your objects will appear in this list.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(editor.board.items.reversed()) { item in
                        let stamp = editor.stamp
                        Button { editor.selectFromList(item.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.kind.symbol).foregroundStyle(item.style.ink.color)
                                Text(item.displayName).lineLimit(2)
                                Spacer(minLength: 0)
                                if editor.selectedIDs.contains(item.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 8)
                            .frame(minHeight: 52, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.kind.title): \(item.displayName)")
                        .accessibilityValue(editor.selectedIDs.contains(item.id) ? "Selected" : "Not selected")
                        .accessibilityHint(editor.isSelectingMultiple
                            ? "Add or remove this object from the selection."
                            : "Select to edit this object in the inspector.")
                        .accessibilityAddTraits(editor.selectedIDs.contains(item.id) ? .isSelected : [])
                        .contextMenu {
                            Group {
                                Button("Edit object") {
                                    guard editor.board.items.contains(where: { $0.id == item.id }) else { return }
                                    editor.select(item.id); editor.editSelected()
                                }
                                Button("Duplicate") { onCommand(.duplicate(id: item.id, newID: UUID(), offset: BoardPoint(x: 24, y: 24)), stamp) }
                                Button("Bring to front") { onCommand(.bringToFront(item.id), stamp) }
                                Button("Send to back") { onCommand(.sendToBack(item.id), stamp) }
                                Button("Delete", role: .destructive) { onCommand(.delete(item.id), stamp) }
                            }
                            .disabled(!isEditable)
                        }
                    }
                }
                .listStyle(.plain)
            }
            Text("\(editor.board.items.count) of 500 objects · \(editor.selectedIDs.count) selected · Frontmost first")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
        .frame(minWidth: 190, idealWidth: 220, maxWidth: 250)
    }
}
