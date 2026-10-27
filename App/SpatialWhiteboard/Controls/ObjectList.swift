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
                        Button { editor.select(item.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.kind.symbol).foregroundStyle(item.style.ink.color)
                                Text(item.displayName).lineLimit(2)
                                Spacer(minLength: 0)
                                if editor.selectedID == item.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 8)
                            .frame(minHeight: 52, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.kind.title): \(item.displayName)")
                        .accessibilityValue(editor.selectedID == item.id ? "Selected" : "")
                        .accessibilityHint("Select to edit this object in the inspector.")
                        .accessibilityAddTraits(editor.selectedID == item.id ? .isSelected : [])
                        .contextMenu {
                            Group {
                                Button("Edit object") { editor.select(item.id); editor.editSelected() }
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
            Text("\(editor.board.items.count) of 500 objects · Frontmost first")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
        .frame(minWidth: 190, idealWidth: 220, maxWidth: 250)
    }
}
