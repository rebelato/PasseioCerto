import SwiftUI
#if canImport(UIKit)
import UIKit

/// Pinch to zoom and two-finger pan for the big grids, while one finger keeps drawing on the
/// board. The board is hosted inside a UIScrollView whose pan needs two touches.
struct ZoomableBoard<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    var maximumZoom: CGFloat = 3
    /// True while zoomed in, so the screen can offer a way back to the whole grid.
    @Binding var zoomed: Bool
    /// Changing this value zooms back out to the whole grid.
    var resetToken = 0
    /// Called when a pinch or two-finger pan starts (true) and ends (false).
    var onGesture: (Bool) -> Void = { _ in }
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(host: UIHostingController(rootView: content()), zoomed: $zoomed) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = BoardScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = maximumZoom
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .clear
        scroll.panGestureRecognizer.minimumNumberOfTouches = 2
        scroll.delaysContentTouches = false
        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: contentSize)
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        scroll.addSubview(host.view)
        scroll.contentSize = contentSize
        scroll.pinchGestureRecognizer?.addTarget(context.coordinator, action: #selector(Coordinator.zoomGesture(_:)))
        scroll.panGestureRecognizer.addTarget(context.coordinator, action: #selector(Coordinator.zoomGesture(_:)))
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.host.rootView = content()
        coordinator.zoomed = $zoomed
        coordinator.onGesture = onGesture
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

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let host: UIHostingController<Content>
        var zoomed: Binding<Bool>
        var resetToken = 0
        var onGesture: (Bool) -> Void = { _ in }
        init(host: UIHostingController<Content>, zoomed: Binding<Bool>) { self.host = host; self.zoomed = zoomed }
        @objc func zoomGesture(_ recognizer: UIGestureRecognizer) {
            switch recognizer.state {
            case .began: onGesture(true)
            case .ended, .cancelled, .failed: onGesture(false)
            default: break
            }
        }
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

/// The board's own drawing gesture grabs every touch as soon as a finger lands, which kept the
/// pinch from ever starting over the grid. Letting pinch and two-finger pan run alongside it fixes
/// that; the screen drops any half-drawn stroke when they begin, and ignores the lifting fingers.
private final class BoardScrollView: UIScrollView {
    @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        gestureRecognizer === pinchGestureRecognizer || gestureRecognizer === panGestureRecognizer
    }
}
#endif
