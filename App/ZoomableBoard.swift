import SwiftUI
#if canImport(UIKit)
import UIKit

/// One-finger touches on a zoomable board, in board coordinates (row/column 0 are the clues).
struct BoardTouchHandlers {
    var cellSide: CGFloat
    var rows: Int
    var columns: Int
    var enabled: Bool
    var onTap: (Cell, Bool) -> Void
    var onStrokeStart: (Cell) -> Void
    var onStrokeMove: (Cell?) -> Void
    var onStrokeEnd: (Bool) -> Void
}

/// Pinch to zoom and two-finger pan for the big grids, while one finger keeps drawing.
/// SwiftUI's drawing gesture swallowed every touch and kept the pinch from starting over the
/// grid, so here both live in UIKit: the scroll view pinches and pans with two fingers, and a
/// one-finger recognizer on the board does what PuzzleBoard's gesture does elsewhere.
struct ZoomableBoard<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    var maximumZoom: CGFloat = 3
    /// True while zoomed in, so the screen can offer a way back to the whole grid.
    @Binding var zoomed: Bool
    /// Changing this value zooms back out to the whole grid.
    var resetToken = 0
    var touches: BoardTouchHandlers
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(host: UIHostingController(rootView: content()), zoomed: $zoomed, touches: touches) }
    func makeUIView(context: Context) -> UIScrollView {
        let coordinator = context.coordinator
        let scroll = UIScrollView()
        scroll.delegate = coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = maximumZoom
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .clear
        scroll.panGestureRecognizer.minimumNumberOfTouches = 2
        scroll.delaysContentTouches = false
        let host = coordinator.host
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: contentSize)
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        scroll.addSubview(host.view)
        scroll.contentSize = contentSize
        // A press with no delay and unlimited movement follows one finger from down to up.
        let finger = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.finger(_:)))
        finger.minimumPressDuration = 0
        finger.allowableMovement = .greatestFiniteMagnitude
        finger.delegate = coordinator
        host.view.addGestureRecognizer(finger)
        scroll.pinchGestureRecognizer?.addTarget(coordinator, action: #selector(Coordinator.twoFingers(_:)))
        scroll.panGestureRecognizer.addTarget(coordinator, action: #selector(Coordinator.twoFingers(_:)))
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.host.rootView = content()
        coordinator.zoomed = $zoomed
        coordinator.touches = touches
        scroll.maximumZoomScale = maximumZoom
        if coordinator.host.view.bounds.size != contentSize {
            scroll.zoomScale = 1
            coordinator.host.view.frame = CGRect(origin: .zero, size: contentSize)
            scroll.contentSize = contentSize
        }
        if coordinator.resetToken != resetToken {
            coordinator.resetToken = resetToken
            scroll.setZoomScale(1, animated: true)
        }
        coordinator.center(in: scroll)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let host: UIHostingController<Content>
        var zoomed: Binding<Bool>
        var touches: BoardTouchHandlers
        var resetToken = 0
        private var startCell: Cell?
        private var startTime = Date()
        private var stroking = false
        /// Set when a second finger turns the touch into a zoom: nothing is drawn or tapped.
        private var abandoned = false
        init(host: UIHostingController<Content>, zoomed: Binding<Bool>, touches: BoardTouchHandlers) {
            self.host = host; self.zoomed = zoomed; self.touches = touches
        }
        private func cell(at point: CGPoint) -> Cell? {
            BoardHitTest.cell(x: point.x, y: point.y, side: touches.cellSide, rows: touches.rows, columns: touches.columns)
        }
        @objc func finger(_ recognizer: UILongPressGestureRecognizer) {
            let current = cell(at: recognizer.location(in: host.view))
            switch recognizer.state {
            case .began:
                abandoned = !touches.enabled || recognizer.numberOfTouches > 1
                stroking = false; startCell = current; startTime = Date()
            case .changed:
                if recognizer.numberOfTouches > 1 { abandon(); return }
                guard !abandoned, let start = startCell else { return }
                if !stroking {
                    guard current != start else { return }
                    stroking = true; touches.onStrokeStart(start)
                }
                touches.onStrokeMove(current)
            case .ended:
                defer { startCell = nil; stroking = false }
                guard !abandoned, let start = startCell else { return }
                if stroking { touches.onStrokeEnd(false) }
                else { touches.onTap(start, Date().timeIntervalSince(startTime) >= 0.45) }
            case .cancelled, .failed:
                if stroking && !abandoned { touches.onStrokeEnd(true) }
                startCell = nil; stroking = false
            default: break
            }
        }
        /// A pinch or two-finger pan beginning abandons whatever the first finger was doing.
        @objc func twoFingers(_ recognizer: UIGestureRecognizer) {
            if recognizer.state == .began { abandon() }
        }
        private func abandon() {
            if stroking && !abandoned { touches.onStrokeEnd(true) }
            abandoned = true; stroking = false
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            center(in: scrollView)
            let isZoomed = scrollView.zoomScale > 1.01
            if zoomed.wrappedValue != isZoomed { zoomed.wrappedValue = isZoomed }
        }
        /// Keeps the board centred while it is smaller than the visible area.
        func center(in scroll: UIScrollView) {
            let size = host.view.frame.size
            let x = max(0, (scroll.bounds.width - size.width) / 2)
            let y = max(0, (scroll.bounds.height - size.height) / 2)
            scroll.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
        }
    }
}
#endif
