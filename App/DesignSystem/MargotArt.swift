import SwiftUI

/// Original vector artwork, informed by the user's photographs of Margot.
/// Coordinates use a 200 × 200 design canvas; photos are never bundled.
enum MargotPose: String { case idle = "MargotIdle", walking = "MargotWalking", happy = "MargotHappy" }
struct MargotArt: View {
    var pose: MargotPose = .idle
    private let fur = Color(red: 0.98, green: 0.97, blue: 0.92)
    private let cream = Color(red: 0.85, green: 0.81, blue: 0.70)
    private let ink = Color(red: 0.12, green: 0.15, blue: 0.13)
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Long, dropped ears distinguish Margot from a generic teddy face.
                ForEach([-1.0, 1.0], id: \.self) { sign in
                    ZStack {
                        Ellipse().fill(cream).frame(width: 49, height: 99)
                        Ellipse().fill(fur.opacity(0.65)).frame(width: 38, height: 85).offset(x: -sign*3, y: -3)
                        ForEach(0..<5) { i in
                            Curlicue().stroke(cream, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .frame(width: 16, height: 13).offset(x: i.isMultiple(of: 2) ? -7 : 6, y: CGFloat(i*15-30))
                        }
                    }.rotationEffect(.degrees(sign * (pose == .walking ? 17 : 8)))
                        .offset(x: sign*66, y: pose == .walking ? 1 : 9)
                }
                Ellipse().fill(cream).frame(width: 141, height: 145).offset(y: -10)
                Ellipse().fill(fur).frame(width: 135, height: 140).offset(y: -12)
                ForEach(0..<11) { i in
                    let angle = Double(i)*Double.pi/10 + Double.pi
                    Circle().fill(fur).frame(width: 28, height: 28)
                        .offset(x: cos(angle)*57, y: sin(angle)*57-21)
                }
                ForEach(0..<6) { i in
                    Curlicue().stroke(cream.opacity(0.62), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 18, height: 12)
                        .offset(x: CGFloat((i%3)*27-27), y: CGFloat((i/3)*18-60))
                }
                ForEach([-1.0, 1.0], id: \.self) { sign in
                    Ellipse().fill(cream.opacity(0.5)).frame(width: 28, height: 30).offset(x: sign*28, y: -7)
                    Ellipse().fill(ink).frame(width: 20, height: 24).offset(x: sign*28, y: -10)
                    Circle().fill(.white).frame(width: 6, height: 6).offset(x: sign*28-3, y: -16)
                }
                // Rounded, slightly elongated muzzle and small black nose.
                Ellipse().fill(cream.opacity(0.65)).frame(width: 76, height: 56).offset(y: 27)
                Ellipse().fill(fur).frame(width: 74, height: 53).offset(y: 24)
                if pose == .happy {
                    Ellipse().fill(ink).frame(width: 29, height: 24).offset(y: 51)
                    RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.81, green: 0.43, blue: 0.46))
                        .frame(width: 17, height: 23).offset(y: 58)
                } else {
                    Path { p in
                        p.move(to: CGPoint(x: 87, y: 146))
                        p.addQuadCurve(to: CGPoint(x: 113, y: 146), control: CGPoint(x: 100, y: 153))
                    }.stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                RoundedRectangle(cornerRadius: 8).fill(ink).frame(width: 28, height: 20).offset(y: 26)
                Ellipse().fill(.white.opacity(0.35)).frame(width: 10, height: 4).offset(x: -4, y: 21)
                ForEach([-1.0, 1.0], id: \.self) { sign in
                    Curlicue().stroke(cream, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 17, height: 12).offset(x: sign*43, y: 28)
                }
            }.frame(width: 200, height: 200)
                .scaleEffect(min(proxy.size.width, proxy.size.height)/200, anchor: .topLeading)
        }.accessibilityHidden(true)
    }
}
private struct Curlicue: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addCurve(to: CGPoint(x: rect.maxX*0.6, y: rect.maxY*0.8),
                       control1: CGPoint(x: rect.minX, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX*0.35, y: rect.midY), control: CGPoint(x: rect.maxX*0.25, y: rect.maxY))
        }
    }
}
struct GardenHouseArt: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.95, green: 0.89, blue: 0.74))
                    .frame(width: 122, height: 102).offset(y: 27)
                Path { p in
                    p.move(to: CGPoint(x: 20, y: 93)); p.addLine(to: CGPoint(x: 100, y: 24))
                    p.addLine(to: CGPoint(x: 180, y: 93)); p.addLine(to: CGPoint(x: 167, y: 107))
                    p.addLine(to: CGPoint(x: 100, y: 50)); p.addLine(to: CGPoint(x: 33, y: 107)); p.closeSubpath()
                }.fill(Color(red: 0.65, green: 0.32, blue: 0.20))
                UnevenRoundedRectangle(topLeadingRadius: 23, topTrailingRadius: 23)
                    .fill(Color(red: 0.18, green: 0.34, blue: 0.24)).frame(width: 45, height: 67).offset(y: 45)
            }.frame(width: 200, height: 200).scaleEffect(min(proxy.size.width, proxy.size.height)/200, anchor: .topLeading)
        }.accessibilityHidden(true)
    }
}
struct GardenShrubArt: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule().fill(Color(red: 0.40, green: 0.48, blue: 0.29)).frame(width: 115, height: 25).offset(y: 55)
                ForEach(0..<3) { i in
                    Ellipse().fill(i == 1 ? Color(red: 0.36, green: 0.51, blue: 0.33) : Color(red: 0.49, green: 0.61, blue: 0.40))
                        .frame(width: 65, height: i == 1 ? 110 : 78).offset(x: CGFloat(i-1)*38, y: i == 1 ? -3 : 14)
                }
                Path { p in p.move(to: CGPoint(x: 100, y: 145)); p.addLine(to: CGPoint(x: 100, y: 65)) }
                    .stroke(Color(red: 0.82, green: 0.86, blue: 0.65), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }.frame(width: 200, height: 200).scaleEffect(min(proxy.size.width, proxy.size.height)/200, anchor: .topLeading)
        }.accessibilityHidden(true)
    }
}
