import SwiftUI
import Combine
import UniformTypeIdentifiers
import BoardCore

@MainActor
struct BoardEditor: View {
    @Binding private var document: BoardDocument
    let isEditable: Bool
    @Environment(\.undoManager) private var undoManager
    @State private var editor: EditorState
    @State private var exportRequest: BoardExportRequest?
    @State private var showingExporter = false

    init(document: Binding<BoardDocument>, isEditable: Bool) {
        _document = document
        self.isEditable = isEditable
        _editor = State(initialValue: EditorState(board: document.wrappedValue.board))
    }

    var body: some View {
        let request = exportRequest
        NavigationStack {
            HStack(spacing: 0) {
                if editor.showObjects {
                    ObjectList(editor: editor, isEditable: isEditable, onAdd: addObject, onCommand: command)
                    Divider()
                }
                VStack(spacing: 0) {
                    BoardToolbar(editor: editor, isEditable: isEditable)
                    Divider()
                    BoardCanvas(editor: editor, isEditable: isEditable, onCommit: command)
                    Divider()
                    viewportControls
                }
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                if editor.showInspector {
                    Divider()
                    BoardInspector(editor: editor, isEditable: isEditable, onCommand: command)
                }
            }
            .navigationTitle(editor.board.title)
            .toolbar { editorToolbar }
        }
        .frame(minWidth: 900, minHeight: 640)
        .onAppear { configureUndo() }
        .onChange(of: document.board) { _, board in editor.receive(board); refreshUndo() }
        .onChange(of: isEditable) { _, value in if !value { editor.choose(.select) } }
        .onChange(of: undoManager.map { ObjectIdentifier($0) }) { _, _ in configureUndo() }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { historyChanged($0) }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { historyChanged($0) }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup)) { refreshUndo($0) }
        .sheet(item: $editor.itemEditor) { context in
            ItemEditorSheet(context: context, isEditable: isEditable, onApply: apply)
        }
        .sheet(item: $editor.titleEditor) { context in
            BoardTitleSheet(context: context, isEditable: isEditable, onApply: apply)
        }
        .alert(item: $editor.issue) { issue in
            Alert(title: Text("Action could not complete"), message: Text(issue.message), dismissButton: .default(Text("OK")))
        }
        .fileExporter(isPresented: $showingExporter, document: request?.document,
                      contentTypes: [request?.type ?? .json], defaultFilename: request?.filename ?? "Board",
                      onCompletion: { result in
            if case .failure(let error) = result { finishExport(request?.id, error: error) }
            else { finishExport(request?.id) }
        }, onCancellation: { finishExport(request?.id) })
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { editor.cancelGesture(); undoManager?.undo(); refreshUndo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(!isEditable || !editor.canUndo)
            Button { editor.cancelGesture(); undoManager?.redo(); refreshUndo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
                .disabled(!isEditable || !editor.canRedo)
            Button {
                editor.cancelGesture()
                editor.titleEditor = BoardTitleContext(title: editor.board.title, stamp: editor.stamp)
            } label: { Label("Edit board title", systemImage: "pencil") }
            .disabled(!isEditable)
            Menu {
                Button(editor.showObjects ? "Hide objects" : "Show objects") { editor.showObjects.toggle() }
                Button(editor.showInspector ? "Hide inspector" : "Show inspector") { editor.showInspector.toggle() }
            } label: { Label("Panels", systemImage: "sidebar.left") }
            Menu {
                Button("Export board JSON copy…") { prepareExport(.json) }
                Button("Export SVG image…") { prepareExport(.svg) }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
            .disabled(exportRequest != nil)
        }
    }

    private var viewportControls: some View {
        HStack(spacing: 12) {
            Text("\(editor.board.items.count) objects").font(.caption).foregroundStyle(.secondary)
            if !isEditable { Text("Read only").font(.caption) }
            Spacer(minLength: 8)
            Button { editor.zoom(by: 1 / 1.25) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass").labelStyle(.iconOnly) }
                .accessibilityLabel("Zoom out")
            Text(editor.viewport.scale.formatted(.percent.precision(.fractionLength(0...1))))
                .monospacedDigit().frame(minWidth: 62)
                .accessibilityLabel("Zoom \(editor.viewport.scale.formatted(.percent))")
            Button { editor.zoom(by: 1.25) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass").labelStyle(.iconOnly) }
                .accessibilityLabel("Zoom in")
            Button("Fit") { editor.fit() }.accessibilityLabel("Fit all objects")
            Button("Reset") { editor.resetView() }.accessibilityLabel("Reset view to 100 percent at origin")
        }
        .padding(12)
    }

    private func apply(_ edit: BoardEdit, _ stamp: EditStamp) -> String? {
        guard isEditable else { return "This document is read only." }
        do {
            let candidate = try editor.perform(edit, stamp: stamp, source: document.board)
            if candidate != document.board { document.board = candidate }
            refreshUndo()
            return nil
        } catch { return error.localizedDescription }
    }

    private func command(_ edit: BoardEdit, _ stamp: EditStamp) {
        if let message = apply(edit, stamp) { editor.issue = EditorIssue(message: message) }
    }

    private func addObject(_ kind: BoardKind) {
        guard isEditable else { return }
        editor.receive(document.board)
        editor.cancelGesture()
        do {
            let item = try editor.prepareObject(kind)
            if kind == .text {
                editor.itemEditor = ItemEditorContext(item: item, isNew: true, stamp: editor.stamp)
            } else { command(.add(item), editor.stamp) }
        } catch { editor.report(error) }
    }

    private func prepareExport(_ type: UTType) {
        guard exportRequest == nil else { return }
        do {
            let snapshot = document.board
            let data: Data
            if type == .svg { data = try BoardSVG.encode(snapshot) }
            else { data = try BoardCodec.encode(snapshot) }
            exportRequest = BoardExportRequest(document: ExportDocument(data: data), type: type,
                                               filename: BoardPresentation.exportName(snapshot.title))
            showingExporter = true
        } catch { editor.report(error) }
    }

    private func finishExport(_ id: UUID?, error: Error? = nil) {
        guard let id, exportRequest?.id == id else { return }
        showingExporter = false
        exportRequest = nil
        if let error, (error as? CocoaError)?.code != .userCancelled { editor.report(error) }
    }

    private func configureUndo() {
        undoManager?.levelsOfUndo = 20
        refreshUndo()
    }

    private func refreshUndo(_ notification: Notification? = nil) {
        if let notification {
            guard let manager = notification.object as? UndoManager, manager === undoManager else { return }
        }
        editor.canUndo = undoManager?.canUndo ?? false
        editor.canRedo = undoManager?.canRedo ?? false
    }

    private func historyChanged(_ notification: Notification) {
        guard let manager = notification.object as? UndoManager, manager === undoManager else { return }
        editor.receive(document.board)
        editor.historyDidChange()
        refreshUndo()
    }
}
