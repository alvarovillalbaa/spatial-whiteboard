import SwiftUI
import BoardCore

struct CanvasGesture {
    let stamp: EditStamp
    let tool: EditorTool
    let selectedIDs: Set<UUID>
    let selectionBefore: Set<UUID>
    let hitID: UUID?
    let selectsMultiple: Bool
    let objectID: UUID
    let start: BoardPoint
    let viewport: BoardViewport
    let style: BoardStyle
    let originals: [BoardItem]
    var points: [BoardPoint]
    var previews: [BoardItem] = []
    var offset = BoardPoint(x: 0, y: 0)
    var hasDragged = false
}

extension EditorState {
    func updateGesture(_ value: DragGesture.Value, size: CGSize, isEditable: Bool) {
        if !gestureInProgress {
            gestureInProgress = true
            interactionID = UUID()
        }
        guard !gestureBlocked else { return }
        do {
            if gesture == nil {
                let start = viewport.worldPoint(value.startLocation, in: size)
                let selectionBefore = selectedIDs
                var hit: BoardItem?
                if tool == .select {
                    for item in board.items.reversed() {
                        if try BoardGeometry.hitTest(item, at: start, tolerance: 10 / viewport.scale) {
                            hit = item
                            break
                        }
                    }
                    if let hit, !selectedIDs.contains(hit.id) {
                        try setGestureSelection(isSelectingMultiple ? selectedIDs.union([hit.id]) : [hit.id])
                    }
                }
                gesture = CanvasGesture(stamp: stamp, tool: tool, selectedIDs: selectedIDs,
                                        selectionBefore: selectionBefore, hitID: hit?.id,
                                        selectsMultiple: isSelectingMultiple,
                                        objectID: UUID(), start: start, viewport: viewport,
                                        style: style, originals: hit == nil ? [] : selectedItems,
                                        points: [start])
            }
            guard var draft = gesture,
                  draft.stamp == stamp, draft.tool == tool, draft.selectedIDs == selectedIDs,
                  draft.selectsMultiple == isSelectingMultiple else {
                cancelGesture()
                return
            }
            let end = draft.viewport.worldPoint(value.location, in: size)
            draft.hasDragged = draft.hasDragged
                || hypot(Double(value.translation.width), Double(value.translation.height)) >= 4
            if tool == .pan {
                viewport.pan(from: draft.viewport, translation: value.translation)
            } else if tool == .select, isEditable, draft.hasDragged, !draft.originals.isEmpty {
                draft.offset = BoardPoint(x: end.x - draft.start.x, y: end.y - draft.start.y)
                draft.previews = try draft.originals.map { try BoardGeometry.translated($0, by: draft.offset) }
            } else if tool == .pen, isEditable {
                if let last = draft.points.last,
                   hypot(end.x - last.x, end.y - last.y) * draft.viewport.scale >= 1 {
                    guard draft.points.count < 10_000 else {
                        throw BoardError.invalid("This stroke reached 10000 points. Release and begin another stroke.")
                    }
                    draft.points.append(end)
                }
                if draft.points.count >= 2 {
                    draft.previews = [try BoardGeometry.stroke(id: draft.objectID, worldPoints: draft.points, style: draft.style)]
                }
            } else if let kind = tool.kind, isEditable {
                draft.previews = [try BoardGeometry.shape(id: draft.objectID, kind: kind,
                                                        from: draft.start, to: end, style: draft.style)]
            }
            gesture = draft
        } catch {
            cancelGesture()
            report(error)
        }
    }

    func finishGesture(isEditable: Bool) -> (BoardEdit, EditStamp)? {
        defer { endInteraction() }
        guard let draft = gesture else { return nil }
        guard draft.stamp == stamp, draft.tool == tool, draft.selectedIDs == selectedIDs,
              draft.selectsMultiple == isSelectingMultiple else { return nil }
        if draft.tool == .select {
            if !draft.hasDragged {
                var selection = draft.selectionBefore
                if let hitID = draft.hitID {
                    if draft.selectsMultiple {
                        if !selection.insert(hitID).inserted { selection.remove(hitID) }
                    } else if !selection.contains(hitID) { selection = [hitID] }
                } else { selection.removeAll() }
                do { try setGestureSelection(selection) }
                catch { report(error) }
                return nil
            }
            guard isEditable, !draft.originals.isEmpty,
                  draft.offset.x != 0 || draft.offset.y != 0 else { return nil }
            return (.move(ids: draft.originals.map(\.id), offset: draft.offset), draft.stamp)
        }
        guard isEditable, let item = draft.previews.first else { return nil }
        if draft.tool == .text {
            itemEditor = ItemEditorContext(item: item, isNew: true, stamp: draft.stamp)
            return nil
        }
        guard draft.tool.isDrawing else { return nil }
        return (.add(item), draft.stamp)
    }
}
