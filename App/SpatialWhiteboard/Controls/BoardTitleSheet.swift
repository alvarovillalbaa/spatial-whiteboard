import SwiftUI
import BoardCore

@MainActor
struct BoardTitleSheet: View {
    let context: BoardTitleContext
    let isEditable: Bool
    let onApply: (BoardEdit, EditStamp) -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var message: String?

    init(context: BoardTitleContext, isEditable: Bool, onApply: @escaping (BoardEdit, EditStamp) -> String?) {
        self.context = context
        self.isEditable = isEditable
        self.onApply = onApply
        _title = State(initialValue: context.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Board title", text: $title)
                Text("Choose a title up to 80 characters. The document filename is managed separately by the system.")
                    .font(.caption).foregroundStyle(.secondary)
                if let message { Text(message).foregroundStyle(.red) }
            }
            .navigationTitle("Board title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        guard isEditable else { message = "This document is read only."; return }
                        message = onApply(.rename(title.trimmingCharacters(in: .whitespacesAndNewlines)), context.stamp)
                        if message == nil { dismiss() }
                    }
                    .disabled(!isEditable)
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 340)
    }
}
