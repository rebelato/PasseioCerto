import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct Puppy: View {
    var pose: MargotPose = .idle
    var accessory: Accessory?
    var body: some View {
        GardenArtwork(name: pose.rawValue) { MargotArt(pose: pose) }
            .overlay { if let accessory { AccessoryArt(accessory: accessory) } }
            .accessibilityHidden(true)
    }
}
struct GardenHouse: View {
    var body: some View { GardenArtwork(name: "GardenHouse") { GardenHouseArt() }.accessibilityHidden(true) }
}
struct GardenShrub: View {
    var body: some View { GardenArtwork(name: "GardenShrub") { GardenShrubArt() }.accessibilityHidden(true) }
}
private struct GardenArtwork<Fallback: View>: View {
    let name: String
    @ViewBuilder var fallback: () -> Fallback
    var body: some View {
        #if canImport(UIKit)
        if let image = UIImage(named: name) { Image(uiImage: image).resizable().scaledToFit() }
        else { fallback() }
        #else
        if let image = NSImage(named: name) { Image(nsImage: image).resizable().scaledToFit() }
        else { fallback() }
        #endif
    }
}
