import SwiftUI

/// Original vector art for Margot's shop and room, on the same 200-point canvas as
/// ThemedArt and MargotArt, scaled to fit. See docs/artwork.md.
private struct Canvas<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { proxy in
            ZStack { content() }.frame(width: 200, height: 200)
                .scaleEffect(min(proxy.size.width, proxy.size.height)/200, anchor: .topLeading)
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}
private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

/// The preview for any shop item.
struct ShopItemArt: View {
    let item: ShopItem
    var body: some View {
        switch item.category {
        case .food: FoodArt(id: item.id)
        case .accessory: Puppy(accessory: item.accessory)
        case .furniture: FurnitureArt(id: item.id)
        case .toy: ToyArt(id: item.id)
        case .wall: RoundedRectangle(cornerRadius: 12).fill(RoomPalette.wall(item.id)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.1)))
        case .floor: FloorArt(id: item.id).clipShape(RoundedRectangle(cornerRadius: 12))
        case .house: HouseModelArt(id: item.id)
        }
    }
}

enum RoomPalette {
    static func wall(_ id: String) -> Color {
        switch id {
        case "wall.mint": rgb(0.80, 0.91, 0.84)
        case "wall.peach": rgb(0.98, 0.85, 0.76)
        case "wall.lavender": rgb(0.87, 0.84, 0.95)
        default: rgb(0.97, 0.93, 0.84)
        }
    }
}

struct FoodArt: View {
    let id: String
    var body: some View {
        Canvas {
            switch id {
            case "food.treat":
                // A bone-shaped biscuit.
                ZStack {
                    ForEach([-1.0, 1.0], id: \.self) { s in
                        ForEach([-1.0, 1.0], id: \.self) { t in Circle().fill(rgb(0.80, 0.56, 0.32)).frame(width: 46, height: 46).offset(x: s*52, y: t*18) }
                    }
                    RoundedRectangle(cornerRadius: 12).fill(rgb(0.80, 0.56, 0.32)).frame(width: 112, height: 36)
                }.rotationEffect(.degrees(-25))
            case "food.chicken":
                Ellipse().fill(rgb(0.86, 0.55, 0.28)).frame(width: 120, height: 96).offset(x: -16, y: 8)
                Capsule().fill(rgb(0.97, 0.94, 0.86)).frame(width: 70, height: 20).rotationEffect(.degrees(-35)).offset(x: 52, y: -36)
                Circle().fill(rgb(0.97, 0.94, 0.86)).frame(width: 26, height: 26).offset(x: 78, y: -58)
            case "food.cake":
                RoundedRectangle(cornerRadius: 10).fill(rgb(0.96, 0.80, 0.84)).frame(width: 130, height: 70).offset(y: 30)
                RoundedRectangle(cornerRadius: 10).fill(rgb(0.99, 0.95, 0.92)).frame(width: 130, height: 22).offset(y: -2)
                Image(systemName: "pawprint.fill").font(.system(size: 34)).foregroundStyle(rgb(0.75, 0.35, 0.45)).offset(y: 32)
                Capsule().fill(rgb(0.45, 0.65, 0.85)).frame(width: 8, height: 40).offset(y: -32)
                Ellipse().fill(rgb(1, 0.75, 0.25)).frame(width: 14, height: 20).offset(y: -60)
            default:
                // Kibble in a bowl.
                Ellipse().fill(rgb(0.35, 0.55, 0.75)).frame(width: 170, height: 70).offset(y: 40)
                ForEach(0..<9) { i in
                    Circle().fill(rgb(0.62, 0.40, 0.22)).frame(width: 26, height: 26)
                        .offset(x: Double(i % 5 - 2) * 26, y: Double(i / 5) * -16 + 10)
                }
                Capsule().fill(rgb(0.30, 0.48, 0.66)).frame(width: 176, height: 18).offset(y: 22)
            }
        }
    }
}

struct ToyArt: View {
    let id: String
    var body: some View {
        Canvas {
            switch id {
            case "toy.bone":
                ZStack {
                    ForEach([-1.0, 1.0], id: \.self) { s in
                        ForEach([-1.0, 1.0], id: \.self) { t in Circle().fill(rgb(0.95, 0.45, 0.45)).frame(width: 50, height: 50).offset(x: s*58, y: t*20) }
                    }
                    RoundedRectangle(cornerRadius: 14).fill(rgb(0.95, 0.45, 0.45)).frame(width: 120, height: 40)
                }.rotationEffect(.degrees(20))
            case "toy.rope":
                Capsule().fill(rgb(0.30, 0.60, 0.80)).frame(width: 150, height: 30).rotationEffect(.degrees(-20))
                ForEach(0..<5) { i in
                    Capsule().fill(rgb(0.95, 0.95, 0.95)).frame(width: 10, height: 30).rotationEffect(.degrees(-20)).offset(x: Double(i - 2) * 26, y: Double(i - 2) * -9)
                }
                Circle().fill(rgb(0.95, 0.70, 0.30)).frame(width: 36, height: 36).offset(x: -78, y: 28)
                Circle().fill(rgb(0.95, 0.70, 0.30)).frame(width: 36, height: 36).offset(x: 78, y: -28)
            default:
                Circle().fill(rgb(0.70, 0.85, 0.30)).frame(width: 130, height: 130)
                Path { p in
                    p.addArc(center: CGPoint(x: 60, y: 100), radius: 60, startAngle: .degrees(-60), endAngle: .degrees(60), clockwise: false)
                    p.move(to: CGPoint(x: 200, y: 100))
                    p.addArc(center: CGPoint(x: 140, y: 100), radius: 60, startAngle: .degrees(120), endAngle: .degrees(240), clockwise: false)
                }.stroke(.white.opacity(0.85), lineWidth: 6).frame(width: 200, height: 200)
                    .mask(Circle().frame(width: 130, height: 130))
            }
        }
    }
}

struct FurnitureArt: View {
    let id: String
    var body: some View {
        Canvas {
            switch id {
            case "furn.bed":
                Ellipse().fill(rgb(0.62, 0.38, 0.30)).frame(width: 180, height: 90).offset(y: 40)
                Ellipse().fill(rgb(0.95, 0.85, 0.72)).frame(width: 140, height: 56).offset(y: 34)
            case "furn.cushion":
                RoundedRectangle(cornerRadius: 30).fill(rgb(0.90, 0.55, 0.50)).frame(width: 150, height: 90).offset(y: 40)
                Circle().fill(rgb(0.75, 0.40, 0.38)).frame(width: 12, height: 12).offset(y: 40)
            case "furn.plant":
                RoundedRectangle(cornerRadius: 8).fill(rgb(0.80, 0.50, 0.32)).frame(width: 70, height: 60).offset(y: 66)
                ForEach(0..<5) { i in
                    Ellipse().fill(rgb(0.30, 0.60, 0.35)).frame(width: 34, height: 90)
                        .rotationEffect(.degrees(Double(i - 2) * 28), anchor: .bottom).offset(y: -10)
                }
            case "furn.lamp":
                Capsule().fill(rgb(0.35, 0.35, 0.38)).frame(width: 8, height: 120).offset(y: 30)
                Ellipse().fill(rgb(0.35, 0.35, 0.38)).frame(width: 60, height: 14).offset(y: 92)
                Path { p in p.move(to: CGPoint(x: 70, y: 20)); p.addLine(to: CGPoint(x: 130, y: 20)); p.addLine(to: CGPoint(x: 150, y: 70)); p.addLine(to: CGPoint(x: 50, y: 70)); p.closeSubpath() }
                    .fill(rgb(0.98, 0.88, 0.55))
            case "furn.shelf":
                RoundedRectangle(cornerRadius: 6).fill(rgb(0.62, 0.42, 0.28)).frame(width: 130, height: 170).offset(y: 10)
                ForEach(0..<3) { i in
                    Rectangle().fill(rgb(0.95, 0.88, 0.75)).frame(width: 112, height: 42).offset(y: Double(i - 1) * 52 + 10)
                    HStack(spacing: 4) {
                        ForEach(0..<4) { j in RoundedRectangle(cornerRadius: 2).fill([rgb(0.4,0.6,0.8), rgb(0.85,0.5,0.4), rgb(0.5,0.7,0.5), rgb(0.9,0.75,0.4)][(i + j) % 4]).frame(width: 14, height: 34) }
                    }.offset(x: -20, y: Double(i - 1) * 52 + 14)
                }
            case "furn.rug":
                Ellipse().fill(rgb(0.80, 0.45, 0.40)).frame(width: 190, height: 80)
                Ellipse().stroke(rgb(0.98, 0.90, 0.75), lineWidth: 6).frame(width: 150, height: 54)
            case "furn.frame":
                RoundedRectangle(cornerRadius: 6).fill(rgb(0.62, 0.42, 0.28)).frame(width: 140, height: 120)
                RoundedRectangle(cornerRadius: 3).fill(rgb(0.80, 0.90, 0.95)).frame(width: 116, height: 96)
                Puppy(pose: .happy).frame(width: 80, height: 80).offset(y: 4)
            case "furn.clock":
                Circle().fill(rgb(0.62, 0.42, 0.28)).frame(width: 130, height: 130)
                Circle().fill(rgb(0.99, 0.97, 0.92)).frame(width: 110, height: 110)
                Capsule().fill(rgb(0.2, 0.2, 0.2)).frame(width: 6, height: 40).offset(y: -18)
                Capsule().fill(rgb(0.2, 0.2, 0.2)).frame(width: 6, height: 30).rotationEffect(.degrees(90)).offset(x: 14)
            default: EmptyView()
            }
        }
    }
}

struct FloorArt: View {
    let id: String
    var body: some View {
        GeometryReader { proxy in
            switch id {
            case "floor.tiles":
                let side = max(18, proxy.size.width / 8)
                Canvas2D(size: proxy.size) { context in
                    for row in 0...Int(proxy.size.height / side) {
                        for col in 0...Int(proxy.size.width / side) {
                            let light = (row + col) % 2 == 0
                            context.fill(Path(CGRect(x: CGFloat(col) * side, y: CGFloat(row) * side, width: side, height: side)),
                                         with: .color(light ? rgb(0.96, 0.95, 0.92) : rgb(0.80, 0.86, 0.88)))
                        }
                    }
                }
            case "floor.grass":
                ZStack(alignment: .top) {
                    rgb(0.62, 0.80, 0.45)
                    HStack(spacing: 10) { ForEach(0..<24, id: \.self) { _ in Capsule().fill(rgb(0.50, 0.70, 0.36)).frame(width: 4, height: 12) } }.padding(.top, 6)
                }
            default:
                VStack(spacing: 2) {
                    ForEach(0..<6, id: \.self) { i in Rectangle().fill(i % 2 == 0 ? rgb(0.82, 0.64, 0.45) : rgb(0.78, 0.60, 0.42)) }
                }.background(rgb(0.62, 0.45, 0.30))
            }
        }
    }
}
private struct Canvas2D: View {
    let size: CGSize
    let draw: (inout GraphicsContext) -> Void
    var body: some View {
        SwiftUI.Canvas { context, _ in var c = context; draw(&c) }.frame(width: size.width, height: size.height)
    }
}

/// The house at the end of the walk, in the model Margot owns.
struct HouseModelArt: View {
    let id: String
    var body: some View {
        switch id {
        case "house.cottage":
            Canvas {
                RoundedRectangle(cornerRadius: 10).fill(rgb(0.70, 0.84, 0.92)).frame(width: 126, height: 96).offset(y: 34)
                Path { p in p.move(to: CGPoint(x: 18, y: 96)); p.addLine(to: CGPoint(x: 100, y: 28)); p.addLine(to: CGPoint(x: 182, y: 96)); p.closeSubpath() }
                    .fill(rgb(0.30, 0.50, 0.40))
                RoundedRectangle(cornerRadius: 3).fill(rgb(0.60, 0.40, 0.25)).frame(width: 18, height: 40).offset(x: 46, y: -50)
                UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20).fill(rgb(0.95, 0.85, 0.60)).frame(width: 40, height: 58).offset(y: 52)
                Circle().fill(rgb(0.98, 0.95, 0.80)).frame(width: 26, height: 26).offset(x: -38, y: 20)
            }
        case "house.castle":
            Canvas {
                Rectangle().fill(rgb(0.88, 0.86, 0.92)).frame(width: 130, height: 100).offset(y: 40)
                ForEach([-1.0, 1.0], id: \.self) { s in
                    Rectangle().fill(rgb(0.80, 0.78, 0.88)).frame(width: 40, height: 140).offset(x: s * 70, y: 20)
                    Path { p in p.move(to: CGPoint(x: 100 + s*70 - 26, y: -50 + 100)); p.addLine(to: CGPoint(x: 100 + s*70, y: 4)); p.addLine(to: CGPoint(x: 100 + s*70 + 26, y: 50)); p.closeSubpath() }
                        .fill(rgb(0.70, 0.35, 0.50))
                }
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22).fill(rgb(0.45, 0.30, 0.25)).frame(width: 44, height: 60).offset(y: 60)
                Rectangle().fill(rgb(0.70, 0.35, 0.50)).frame(width: 4, height: 30).offset(y: -18)
                Path { p in p.move(to: CGPoint(x: 102, y: 68)); p.addLine(to: CGPoint(x: 124, y: 75)); p.addLine(to: CGPoint(x: 102, y: 82)); p.closeSubpath() }.fill(rgb(0.95, 0.75, 0.25))
            }
        default:
            GardenHouse()
        }
    }
}
