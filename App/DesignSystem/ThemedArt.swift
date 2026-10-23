import SwiftUI

/// Original vector art for themed cells and Margot's accessories, drawn on the same
/// 200-point canvas as MargotArt and scaled to fit. See docs/artwork.md.
private struct Canvas<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { proxy in
            ZStack { content() }.frame(width: 200, height: 200)
                .scaleEffect(min(proxy.size.width, proxy.size.height)/200, anchor: .topLeading)
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}
private let boneColor = Color(red: 0.97, green: 0.93, blue: 0.82)
private let boneEdge = Color(red: 0.72, green: 0.62, blue: 0.45)

struct BoneArt: View {
    var body: some View {
        Canvas {
            ZStack {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    ForEach([-1.0, 1.0], id: \.self) { lobe in
                        Circle().fill(boneColor).overlay(Circle().stroke(boneEdge, lineWidth: 6))
                            .frame(width: 52, height: 52).offset(x: side*58, y: lobe*20)
                    }
                }
                RoundedRectangle(cornerRadius: 14).fill(boneColor).frame(width: 128, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(boneEdge, lineWidth: 6).mask(Rectangle().frame(width: 96, height: 60)))
            }.rotationEffect(.degrees(-30))
        }
    }
}
struct TreeArt: View {
    var body: some View {
        Canvas {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.52, green: 0.34, blue: 0.20)).frame(width: 34, height: 80).offset(y: 58)
            Circle().fill(Color(red: 0.27, green: 0.47, blue: 0.29)).frame(width: 150, height: 150).offset(y: -20)
            Circle().fill(Color(red: 0.36, green: 0.58, blue: 0.36)).frame(width: 90, height: 90).offset(x: -26, y: -42)
            Circle().fill(Color(red: 0.86, green: 0.36, blue: 0.32)).frame(width: 16, height: 16).offset(x: 34, y: -12)
            Circle().fill(Color(red: 0.86, green: 0.36, blue: 0.32)).frame(width: 14, height: 14).offset(x: -8, y: 18)
        }
    }
}
struct CatArt: View {
    private let fur = Color(red: 0.93, green: 0.58, blue: 0.28)
    private let dark = Color(red: 0.25, green: 0.18, blue: 0.13)
    var body: some View {
        Canvas {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Path { p in
                    p.move(to: CGPoint(x: 100 + side*30, y: 70)); p.addLine(to: CGPoint(x: 100 + side*62, y: 22))
                    p.addLine(to: CGPoint(x: 100 + side*70, y: 92)); p.closeSubpath()
                }.fill(fur)
            }
            Ellipse().fill(fur).frame(width: 150, height: 128).offset(y: 18)
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(dark).frame(width: 12, height: 26).offset(x: side*30, y: 8)
                ForEach([-1.0, 1.0], id: \.self) { whisker in
                    Capsule().fill(dark.opacity(0.6)).frame(width: 46, height: 3)
                        .rotationEffect(.degrees(whisker*10)).offset(x: side*62, y: 40 + whisker*8)
                }
            }
            Path { p in p.move(to: CGPoint(x: 92, y: 132)); p.addLine(to: CGPoint(x: 108, y: 132)); p.addLine(to: CGPoint(x: 100, y: 142)); p.closeSubpath() }
                .fill(Color(red: 0.82, green: 0.42, blue: 0.48))
        }
    }
}
struct PuddleArt: View {
    var body: some View {
        Canvas {
            Ellipse().fill(Color(red: 0.55, green: 0.73, blue: 0.86).opacity(0.9)).frame(width: 176, height: 110)
            Ellipse().fill(Color(red: 0.75, green: 0.87, blue: 0.95)).frame(width: 70, height: 18).offset(x: -30, y: -20)
            Ellipse().stroke(Color(red: 0.38, green: 0.58, blue: 0.74), lineWidth: 5).frame(width: 176, height: 110)
        }
    }
}

/// Worn on top of Margot's portrait; positions follow MargotArt's face.
struct AccessoryArt: View {
    let accessory: Accessory
    var body: some View {
        Canvas {
            switch accessory {
            case .bow:
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse().fill(Color(red: 0.89, green: 0.40, blue: 0.52)).frame(width: 40, height: 30)
                        .rotationEffect(.degrees(side*25)).offset(x: 40 + side*20, y: -72)
                }
                Circle().fill(Color(red: 0.75, green: 0.27, blue: 0.40)).frame(width: 16, height: 16).offset(x: 40, y: -72)
            case .bandana:
                Path { p in
                    p.move(to: CGPoint(x: 52, y: 150)); p.addLine(to: CGPoint(x: 148, y: 150)); p.addLine(to: CGPoint(x: 100, y: 196)); p.closeSubpath()
                }.fill(Color(red: 0.84, green: 0.29, blue: 0.24))
                ForEach(0..<3) { i in Circle().fill(.white.opacity(0.85)).frame(width: 8, height: 8).offset(x: CGFloat(i-1)*20, y: 62 + (i == 1 ? 12 : 0)) }
            case .hat:
                Capsule().fill(Color(red: 0.86, green: 0.75, blue: 0.48)).frame(width: 130, height: 22).offset(y: -66)
                RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.90, green: 0.80, blue: 0.54)).frame(width: 78, height: 50).offset(y: -88)
                Rectangle().fill(Color(red: 0.31, green: 0.52, blue: 0.40)).frame(width: 78, height: 10).offset(y: -72)
            case .glasses:
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Circle().stroke(Color(red: 0.15, green: 0.18, blue: 0.20), lineWidth: 6).frame(width: 46, height: 46).offset(x: side*28, y: -10)
                }
                Capsule().fill(Color(red: 0.15, green: 0.18, blue: 0.20)).frame(width: 14, height: 5).offset(y: -12)
            }
        }
    }
}
