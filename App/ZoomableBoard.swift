import SwiftUI
#if canImport(UIKit)
import UIKit

/// Pinch to zoom and two-finger pan for the big grids, while one finger keeps drawing on the
/// board. The board is hosted inside a UIScrollView whose pan needs two touches.
struct ZoomableBoard<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    var maximumZoom: CGFloat = 3
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(host: UIHostingController(rootView: content())) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
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
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let host = context.coordinator.host
        host.rootView = content()
        if host.view.bounds.size != contentSize {
            scroll.zoomScale = 1
            host.view.frame = CGRect(origin: .zero, size: contentSize)
            scroll.contentSize = contentSize
        }
        context.coordinator.center(in: scroll)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let host: UIHostingController<Content>
        init(host: UIHostingController<Content>) { self.host = host }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { center(in: scrollView) }
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
