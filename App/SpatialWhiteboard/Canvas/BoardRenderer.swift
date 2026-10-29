import SwiftUI
import BoardCore

enum BoardRenderer {
    static func draw(board: Board, draft: CanvasGesture?, selection: Set<UUID>, viewport: BoardViewport,
                     context: inout GraphicsContext, size: CGSize) throws {
        context.translateBy(x: size.width / 2 + CGFloat(viewport.offsetX),
                            y: size.height / 2 + CGFloat(viewport.offsetY))
        context.scaleBy(x: CGFloat(viewport.scale), y: CGFloat(viewport.scale))
        let previews = draft?.previews ?? []
        let isMoving = draft?.tool == .select
        for item in board.items {
            if isMoving, let preview = previews.first(where: { $0.id == item.id }) {
                var previewContext = context
                previewContext.opacity = 0.75
                try draw(preview, context: &previewContext)
            } else { try draw(item, context: &context) }
        }
        if draft?.tool.isDrawing == true {
            for preview in previews {
                var previewContext = context
                previewContext.opacity = 0.75
                try draw(preview, context: &previewContext)
            }
        }
        let selectedItems = board.items.filter { selection.contains($0.id) }.map { item in
            isMoving ? (previews.first(where: { $0.id == item.id }) ?? item) : item
        }
        for selected in selectedItems {
            let inset = 5 / viewport.scale
            let bounds = rect(selected.frame).insetBy(dx: -inset, dy: -inset)
            context.stroke(Path(bounds), with: .color(.accentColor),
                           style: StrokeStyle(lineWidth: 1.5 / viewport.scale, dash: [6 / viewport.scale, 4 / viewport.scale]))
        }
        if selectedItems.count > 1, let union = try BoardGeometry.bounds(of: selectedItems) {
            let bounds = rect(union).insetBy(dx: -9 / viewport.scale, dy: -9 / viewport.scale)
            context.stroke(Path(bounds), with: .color(.accentColor),
                           style: StrokeStyle(lineWidth: 2 / viewport.scale, dash: [10 / viewport.scale, 5 / viewport.scale]))
        }
    }

    private static func draw(_ item: BoardItem, context: inout GraphicsContext) throws {
        let color = item.style.ink.color
        let stroke = StrokeStyle(lineWidth: item.style.strokeWidth, lineCap: .round, lineJoin: .round)
        switch item.kind {
        case .rectangle, .ellipse:
            let path = item.kind == .rectangle ? Path(rect(item.frame)) : Path(ellipseIn: rect(item.frame))
            if item.style.fill { context.fill(path, with: .color(color.opacity(0.15))) }
            context.stroke(path, with: .color(color), style: stroke)
        case .stroke, .arrow:
            let points = item.points.map { point in
                BoardPoint(x: item.frame.x + point.x * item.frame.width,
                           y: item.frame.y + point.y * item.frame.height)
            }
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: cgPoint(first))
            for point in points.dropFirst() { path.addLine(to: cgPoint(point)) }
            if item.kind == .arrow, points.count == 2 {
                for wing in try BoardGeometry.arrowWings(from: points[0], to: points[1], width: item.style.strokeWidth) {
                    path.move(to: cgPoint(points[1]))
                    path.addLine(to: cgPoint(wing))
                }
            }
            context.stroke(path, with: .color(color), style: stroke)
        case .text:
            var textContext = context
            textContext.clip(to: Path(rect(item.frame)))
            let text = item.text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                let resolved = textContext.resolve(Text(line).font(.system(size: item.style.fontSize)).foregroundColor(color))
                let proposal = CGSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
                let baseline = resolved.firstBaseline(in: proposal)
                let y = item.frame.y + item.style.fontSize + Double(index) * item.style.fontSize * 1.25 - Double(baseline)
                textContext.draw(resolved, at: CGPoint(x: item.frame.x, y: y), anchor: .topLeading)
            }
        }
    }

    private static func rect(_ value: BoardRect) -> CGRect {
        CGRect(x: value.x, y: value.y, width: value.width, height: value.height)
    }

    private static func cgPoint(_ point: BoardPoint) -> CGPoint {
        CGPoint(x: point.x, y: point.y)
    }
}
