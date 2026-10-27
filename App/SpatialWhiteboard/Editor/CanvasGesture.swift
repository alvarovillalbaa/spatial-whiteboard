import SwiftUI
import BoardCore

struct CanvasGesture {
    let stamp: EditStamp
    let tool: EditorTool
    let selectedID: UUID?
    let objectID: UUID
    let start: BoardPoint
    let viewport: BoardViewport
    let style: BoardStyle
    let original: BoardItem?
    var points: [BoardPoint]
    var preview: BoardItem?
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
                var original: BoardItem?
                if tool == .select {
                    for item in board.items.reversed() {
                        if try BoardGeometry.hitTest(item, at: start, tolerance: 10 / viewport.scale) {
                            original = item
                            break
                        }
                    }
                    selectedID = original?.id
                }
                gesture = CanvasGesture(stamp: stamp, tool: tool, selectedID: selectedID,
                                        objectID: UUID(), start: start, viewport: viewport,
                                        style: style, original: original, points: [start])
            }
            guard var draft = gesture,
                  draft.stamp == stamp, draft.tool == tool, draft.selectedID == selectedID else {
                cancelGesture()
                return
            }
            let end = draft.viewport.worldPoint(value.location, in: size)
            if tool == .pan {
                viewport.pan(from: draft.viewport, translation: value.translation)
            } else if tool == .select, isEditable, var item = draft.original {
                item.frame.x += end.x - draft.start.x
                item.frame.y += end.y - draft.start.y
                _ = try BoardGeometry.bounds(of: [item])
                draft.preview = item
            } else if tool == .pen, isEditable {
                if let last = draft.points.last,
                   hypot(end.x - last.x, end.y - last.y) * draft.viewport.scale >= 1 {
                    guard draft.points.count < 10_000 else {
                        throw BoardError.invalid("This stroke reached 10000 points. Release and begin another stroke.")
                    }
                    draft.points.append(end)
                }
                if draft.points.count >= 2 {
                    draft.preview = try BoardGeometry.stroke(id: draft.objectID, worldPoints: draft.points, style: draft.style)
                }
            } else if let kind = tool.kind, isEditable {
                draft.preview = try BoardGeometry.shape(id: draft.objectID, kind: kind,
                                                       from: draft.start, to: end, style: draft.style)
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
        guard isEditable, draft.stamp == stamp, draft.tool == tool,
              draft.selectedID == selectedID, let item = draft.preview else { return nil }
        if draft.tool == .text {
            itemEditor = ItemEditorContext(item: item, isNew: true, stamp: draft.stamp)
            return nil
        }
        if draft.tool == .select {
            guard item != draft.original else { return nil }
            return (.replace(item), draft.stamp)
        }
        guard draft.tool.isDrawing else { return nil }
        return (.add(item), draft.stamp)
    }
}
