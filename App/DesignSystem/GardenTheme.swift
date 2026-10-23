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
    /// The walked route: warm earth, so green is left for satisfied clues and shrubs.
    static let trail = adaptive(0x7A4521, 0xE7B58A)
    static let trailTint = adaptive(0xF3E4CF, 0x463729)
    /// Soil under obstacles, the most legible thing on the board.
    static let soil = adaptive(0xD9C6A3, 0x5A4733)
    static let catZone = adaptive(0xF7E6DF, 0x3B2A27)
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

/// Outlined by default; `prominent` is the one filled call to action on a screen.
struct GardenButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(prominent ? .title3.weight(.bold) : GardenTheme.heading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: prominent ? 60 : GardenTheme.minTarget)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .foregroundStyle(prominent ? GardenTheme.background : enabled ? GardenTheme.ink : GardenTheme.secondary)
            .background(prominent ? GardenTheme.ink.opacity(configuration.isPressed ? 0.8 : 1)
                        : configuration.isPressed ? GardenTheme.sage : GardenTheme.surface,
                        in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .overlay { if !prominent { RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border) } }
            .opacity(enabled ? 1 : 0.55)
    }
}
/// Compact icon-over-label button for the in-game toolbar.
struct GardenIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.labelStyle(.verticalIcon)
            .frame(maxWidth: .infinity, minHeight: GardenTheme.minTarget)
            .padding(.vertical, 6)
            .foregroundStyle(enabled ? GardenTheme.ink : GardenTheme.secondary)
            .background(configuration.isPressed ? GardenTheme.sage : .clear, in: RoundedRectangle(cornerRadius: GardenTheme.cellRadius))
            .opacity(enabled ? 1 : 0.45)
    }
}
struct VerticalIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon.font(.title2)
            configuration.title.font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
extension LabelStyle where Self == VerticalIconLabelStyle {
    static var verticalIcon: VerticalIconLabelStyle { VerticalIconLabelStyle() }
}
struct GardenClue: View {
    let target: Int
    let count: Int
    let label: String
    var blocked = false
    private var symbol: String? { count > target ? "exclamationmark" : count == target ? "checkmark" : nil }
    var body: some View {
        VStack(spacing: 0) {
            Text("\(target)").font(GardenTheme.heading).monospacedDigit()
            if let symbol { Image(systemName: symbol).font(.caption2.bold()) }
        }.foregroundStyle(count > target || blocked ? GardenTheme.error : GardenTheme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(count == target ? GardenTheme.sage : GardenTheme.surface,
                        in: RoundedRectangle(cornerRadius: GardenTheme.cellRadius))
            .overlay { if blocked { RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(GardenTheme.error, lineWidth: 3) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(String(localized: "\(count) de \(target) casas ocupadas. \(count > target ? "Pista excedida" : count == target ? "Contagem atingida" : "Pendente")"))
    }
}
struct GardenNote: View {
    let text: String
    var symbol = "info.circle"
    var body: some View {
        Label { Text(text).font(GardenTheme.body).fixedSize(horizontal: false, vertical: true) }
        icon: { Image(systemName: symbol).font(.title3) }
            .accessibilityElement(children: .combine)
            .foregroundStyle(GardenTheme.ink).frame(maxWidth: .infinity, alignment: .leading)
            .padding(GardenTheme.spacing).background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
    }
}
/// What sits on a cell besides the route.
enum CellFeature { case none, shrub, tree, cat, bone, puddle }
struct GardenCell: View {
    var occupied = false
    var excluded = false
    var obstacle = false
    var highlighted = false
    var blocked = false
    var feature = CellFeature.none
    /// Beside a cat: tinted so the forbidden ring around it reads at a glance.
    var nearCat = false
    private var fill: Color {
        obstacle ? GardenTheme.soil : occupied ? GardenTheme.trailTint : nearCat ? GardenTheme.catZone : GardenTheme.surface
    }
    var body: some View {
        RoundedRectangle(cornerRadius: GardenTheme.cellRadius)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(highlighted ? GardenTheme.accent : GardenTheme.border, lineWidth: highlighted ? 3 : 1))
            .overlay { if blocked { RoundedRectangle(cornerRadius: GardenTheme.cellRadius).fill(GardenTheme.error.opacity(0.35)).strokeBorder(GardenTheme.error, lineWidth: 3) } }
            .overlay {
                switch feature == .none && obstacle ? .shrub : feature {
                case .tree: TreeArt().padding(2)
                case .cat: CatArt().padding(4)
                case .shrub: GardenShrub().padding(2)
                case .puddle: PuddleArt().padding(4).opacity(occupied ? 0.6 : 1)
                case .bone: BoneArt().padding(3).opacity(occupied ? 0.55 : 1)
                case .none: EmptyView()
                }
                if excluded && !obstacle { Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundStyle(GardenTheme.secondary) }
                else if highlighted && !obstacle { Image(systemName: "lightbulb.fill").font(.caption).foregroundStyle(GardenTheme.accent) }
            }
    }
}

/// Tranquilo / Desafiador, chosen before a walk starts.
struct PlayModePicker: View {
    @Binding var selection: PlayMode
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        if textSize.isAccessibilitySize {
            picker.pickerStyle(.menu).frame(minHeight: GardenTheme.minTarget)
        } else { picker.pickerStyle(.segmented) }
    }
    private var picker: some View {
        Picker(String(localized: "Modo do passeio"), selection: $selection) {
            ForEach(PlayMode.allCases, id: \.self) { Text($0.title).tag($0) }
        }
    }
}

/// Earned paws for a finished walk; unearned ones stay outlined.
struct PawScore: View {
    let paws: Int
    var size: Font = .title
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<GameAttempt.maxLives, id: \.self) { index in
                Image(systemName: index < paws ? "pawprint.fill" : "pawprint")
                    .font(size).foregroundStyle(index < paws ? GardenTheme.terracotta : GardenTheme.border)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(paws == 1 ? String(localized: "1 patinha de 3") : String(localized: "\(paws) patinhas de 3"))
    }
}
