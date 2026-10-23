// Run from the repository root using the documented swiftc command in docs/artwork.md.
import SwiftUI
import AppKit
@main struct RenderArtwork {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for pose in [MargotPose.idle, .walking, .happy] {
            try save(MargotArt(pose: pose), side: 512, to: root.appendingPathComponent(pose.rawValue + ".png"))
        }
        try save(GardenHouseArt(), side: 256, to: root.appendingPathComponent("GardenHouse.png"))
        try save(GardenShrubArt(), side: 256, to: root.appendingPathComponent("GardenShrub.png"))
        let icon = GeometryReader { size in
            ZStack {
                Color(red: 0.89, green: 0.93, blue: 0.84)
                Circle().fill(Color(red: 0.98, green: 0.96, blue: 0.91)).padding(size.size.width*0.066)
                MargotArt(pose: .happy).padding(size.size.width*0.064)
            }
        }
        try save(icon, side: 1024, to: root.appendingPathComponent("AppIcon.png"), opaque: true)
        let sheet = VStack(spacing: 16) {
            HStack {
                ForEach([MargotPose.idle, .walking, .happy], id: \.rawValue) { pose in
                    VStack { MargotArt(pose: pose).frame(width: 150, height: 150); Text(pose.rawValue) }
                }
            }
            HStack {
                GardenHouseArt().frame(width: 100, height: 100)
                GardenShrubArt().frame(width: 100, height: 100)
                icon.frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }.padding(20).background(Color(red: 0.98, green: 0.96, blue: 0.91))
        let renderer = ImageRenderer(content: sheet); renderer.scale = 2
        try write(renderer, to: root.appendingPathComponent("artwork-sheet.png"))
    }
    @MainActor static func save<V: View>(_ view: V, side: CGFloat, to url: URL, opaque: Bool = false) throws {
        let renderer = ImageRenderer(content: view.frame(width: side, height: side))
        renderer.scale = 1
        try write(renderer, to: url, opaque: opaque)
    }
    @MainActor static func write<V: View>(_ renderer: ImageRenderer<V>, to url: URL, opaque: Bool = false) throws {
        guard var cg = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        if opaque {
            let context = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            cg = context.makeImage()!
        }
        guard let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
    }
}
