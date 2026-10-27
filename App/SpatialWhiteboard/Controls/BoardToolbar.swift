import SwiftUI

@MainActor
struct BoardToolbar: View {
    let editor: EditorState
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(EditorTool.allCases) { tool in
                        Button { editor.choose(tool) } label: {
                            Label(tool.title, systemImage: tool.symbol)
                                .labelStyle(.iconOnly)
                                .frame(minWidth: 52, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(editor.tool == tool ? .accentColor : .secondary)
                        .disabled(!isEditable && tool.isDrawing)
                        .help(tool.title)
                        .accessibilityLabel(tool.title)
                        .accessibilityAddTraits(editor.tool == tool ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            Text(isEditable ? editor.tool.hint : "Read only. You can select objects, navigate the board and export a copy.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }
}
