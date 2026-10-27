import SwiftUI
import BoardCore

struct BoardViewport: Equatable {
    var scale: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0

    func worldPoint(_ point: CGPoint, in size: CGSize) -> BoardPoint {
        BoardPoint(
            x: (Double(point.x - size.width / 2) - offsetX) / scale,
            y: (Double(point.y - size.height / 2) - offsetY) / scale
        )
    }

    func viewPoint(_ point: BoardPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * scale + offsetX + Double(size.width / 2),
                y: point.y * scale + offsetY + Double(size.height / 2))
    }

    mutating func zoom(by factor: Double) {
        let next = min(8, max(0.001, scale * factor))
        let ratio = next / scale
        offsetX *= ratio
        offsetY *= ratio
        scale = next
    }

    mutating func pan(from initial: BoardViewport, translation: CGSize) {
        offsetX = min(2_000_000, max(-2_000_000, initial.offsetX + Double(translation.width)))
        offsetY = min(2_000_000, max(-2_000_000, initial.offsetY + Double(translation.height)))
    }

    mutating func fit(_ bounds: BoardRect?, in size: CGSize) {
        guard let bounds, size.width > 100, size.height > 100 else {
            self = BoardViewport()
            return
        }
        let availableWidth = max(1, Double(size.width) - 100)
        let availableHeight = max(1, Double(size.height) - 100)
        scale = min(8, max(0.001, min(availableWidth / max(1, bounds.width),
                                    availableHeight / max(1, bounds.height))))
        offsetX = -bounds.center.x * scale
        offsetY = -bounds.center.y * scale
    }
}
