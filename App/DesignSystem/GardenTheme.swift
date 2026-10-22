import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum GardenTheme {
    static let background = adaptive(0xFAF6ED, 0x191F1B)
    static let surface = adaptive(0xFFFCF5, 0x27312A)
    static let sage = adaptive(0xE4EBD9, 0x354735)
    static let ink = adaptive(0x173E2C, 0xE8F2E5)
    static let secondary = adaptive(0x606759, 0xBAC6B6)
    static let border = adaptive(0x8B927E, 0x81927A)
    static let accent = adaptive(0x315F42, 0xA9D3A4)
    static let terracotta = adaptive(0x9B4C2C, 0xE8A585)
    static let error = adaptive(0x9E332A, 0xFFB0A4)
    static let title = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let heading = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .rounded)
    static let spacing: CGFloat = 16
    static let radius: CGFloat = 18
    static let cellRadius: CGFloat = 10
    static let minTarget: CGFloat = 44
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        func components(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 255)/255, CGFloat((hex >> 8) & 255)/255, CGFloat(hex & 255)/255)
        }
        let l = components(light), d = components(dark)
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? d : l
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l
            return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }
}

struct GardenButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(GardenTheme.heading)
            .frame(maxWidth: .infinity, minHeight: GardenTheme.minTarget)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .foregroundStyle(enabled ? GardenTheme.ink : GardenTheme.secondary)
            .background(configuration.isPressed ? GardenTheme.sage : GardenTheme.surface,
                        in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border))
            .opacity(enabled ? 1 : 0.55)
    }
}
struct GardenClue: View {
    let target: Int
    let count: Int
    let label: String
    private var symbol: String? { count > target ? "exclamationmark" : count == target ? "checkmark" : nil }
    var body: some View {
        VStack(spacing: 0) {
            Text("\(target)").font(GardenTheme.heading).monospacedDigit()
            if let symbol { Image(systemName: symbol).font(.caption2.bold()) }
        }.foregroundStyle(count > target ? GardenTheme.error : GardenTheme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(count == target ? GardenTheme.sage : GardenTheme.surface,
                        in: RoundedRectangle(cornerRadius: GardenTheme.cellRadius))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue("\(count) de \(target) casas ocupadas. \(count > target ? "Pista excedida" : count == target ? "Contagem atingida" : "Pendente")")
    }
}
struct GardenNote: View {
    let text: String
    var symbol = "info.circle"
    var body: some View {
        Label { Text(text).font(GardenTheme.body).fixedSize(horizontal: false, vertical: true) }
        icon: { Image(systemName: symbol).font(.title3) }
            .foregroundStyle(GardenTheme.ink).frame(maxWidth: .infinity, alignment: .leading)
            .padding(GardenTheme.spacing).background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
    }
}
struct GardenTools: View {
    @Binding var marking: Bool
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { tool(false); tool(true) }
            VStack(spacing: 8) { tool(false); tool(true) }
        }
    }
    private func tool(_ value: Bool) -> some View {
        Button { marking = value } label: {
            Label(value ? "Marcar ×" : "Caminho", systemImage: value ? "xmark" : "pawprint.fill")
                .font(GardenTheme.heading).padding(.horizontal, 16).padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: GardenTheme.minTarget)
                .foregroundStyle(marking == value ? GardenTheme.background : GardenTheme.ink)
                .background(marking == value ? GardenTheme.ink : GardenTheme.surface, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(marking == value ? .isSelected : [])
    }
}
struct GardenCell: View {
    var occupied = false
    var excluded = false
    var obstacle = false
    var highlighted = false
    var body: some View {
        RoundedRectangle(cornerRadius: GardenTheme.cellRadius)
            .fill(occupied ? GardenTheme.sage : GardenTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(highlighted ? GardenTheme.accent : GardenTheme.border, lineWidth: highlighted ? 3 : 1))
            .overlay {
                if obstacle { Image(systemName: "leaf.fill").foregroundStyle(GardenTheme.secondary) }
                else if excluded { Image(systemName: "xmark").font(.title3).foregroundStyle(GardenTheme.secondary) }
                else if highlighted { Image(systemName: "lightbulb.fill").font(.caption).foregroundStyle(GardenTheme.accent) }
            }
    }
}
