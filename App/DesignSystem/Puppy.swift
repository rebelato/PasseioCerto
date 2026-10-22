import SwiftUI

struct Puppy: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                Ellipse().fill(Color(red: 0.82, green: 0.80, blue: 0.73)).frame(width: w*0.9, height: w*0.65).offset(y: w*0.06)
                ForEach(0..<12) { i in
                    Circle().fill(Color(red: 0.97, green: 0.96, blue: 0.90))
                        .frame(width: w*0.32, height: w*0.32)
                        .offset(x: cos(Double(i)*Double.pi/6)*w*0.29, y: sin(Double(i)*Double.pi/6)*w*0.27)
                }
                Circle().fill(Color(red: 0.97, green: 0.96, blue: 0.90)).frame(width: w*0.65)
                HStack(spacing: w*0.22) {
                    Circle().fill(.black).frame(width: w*0.09)
                    Circle().fill(.black).frame(width: w*0.09)
                }.offset(y: -w*0.03)
                Ellipse().fill(.black).frame(width: w*0.16, height: w*0.11).offset(y: w*0.16)
                HStack { Capsule().fill(Color(red: 0.88, green: 0.86, blue: 0.78)).frame(width: w*0.19, height: w*0.38); Spacer(); Capsule().fill(Color(red: 0.88, green: 0.86, blue: 0.78)).frame(width: w*0.19, height: w*0.38) }.padding(.horizontal, w*0.02)
            }.frame(width: w, height: g.size.height)
        }.accessibilityHidden(true)
    }
}
