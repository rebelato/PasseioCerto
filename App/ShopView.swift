import SwiftUI

enum ShopTab: String, CaseIterable, Identifiable {
    case food, accessory, home, toy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .food: String(localized: "Comida")
        case .accessory: String(localized: "Acessórios")
        case .home: String(localized: "Casa")
        case .toy: String(localized: "Brinquedos")
        }
    }
    var categories: [ShopCategory] {
        switch self {
        case .food: [.food]
        case .accessory: [.accessory]
        case .home: [.furniture, .wall, .floor, .house]
        case .toy: [.toy]
        }
    }
}

/// Everything coins can buy, by tab. Owned items can be used straight from here.
struct ShopView: View {
    @ObservedObject var session: GameSession
    @State var initialTab: ShopTab
    let onClose: () -> Void
    @State private var confirming: ShopItem?
    @State private var note: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker(String(localized: "Seção"), selection: $initialTab) {
                    ForEach(ShopTab.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal, 16)
                if let note { Text(note).font(.footnote).foregroundStyle(GardenTheme.secondary).padding(.horizontal, 16) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(initialTab.categories, id: \.self) { category in
                            if initialTab.categories.count > 1 { Text(category.title).font(GardenTheme.heading) }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                ForEach(ShopCatalog.items(in: category)) { item in card(item) }
                            }
                        }
                    }.padding(16)
                }
            }
            .background(GardenTheme.background).foregroundStyle(GardenTheme.ink)
            .navigationTitle(String(localized: "Loja")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { CoinPill(coins: session.pet.coins).fixedSize() }
                ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Fechar"), action: onClose) }
            }
            .confirmationDialog(confirming.map { String(localized: "Comprar \($0.title) por \($0.price) moedas?") } ?? "",
                                isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                                titleVisibility: .visible, presenting: confirming) { item in
                Button(String(localized: "Comprar")) { buy(item) }
            }
        }.tint(GardenTheme.ink)
    }

    private func card(_ item: ShopItem) -> some View {
        let owned = !item.isConsumable && session.pet.owns(item.id)
        let affordable = session.pet.coins >= item.price
        return VStack(spacing: 8) {
            ShopItemArt(item: item).frame(height: 76).frame(maxWidth: .infinity)
            Text(item.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
            if item.category == .food {
                Text(String(localized: "+\(item.hunger) fome") + (item.joy > 0 ? String(localized: " · +\(item.joy) alegria") : "")
                     + String(localized: " · tem \(session.pet.portions(of: item.id))"))
                    .font(.caption2).foregroundStyle(GardenTheme.secondary)
            }
            if owned {
                if inUse(item) {
                    Label(String(localized: "Em uso"), systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(GardenTheme.accent).frame(minHeight: 34)
                } else if let label = useLabel(item) {
                    Button(label) { use(item) }.buttonStyle(GardenButtonStyle())
                } else {
                    Text(String(localized: "Comprado")).font(.caption.weight(.semibold)).foregroundStyle(GardenTheme.secondary).frame(minHeight: 34)
                }
            } else {
                Button { confirming = item } label: {
                    Label { Text("\(item.price)") } icon: { CoinIcon(size: 16) }
                }.buttonStyle(GardenButtonStyle()).disabled(!affordable)
                    .accessibilityLabel(String(localized: "Comprar por \(item.price) moedas"))
            }
        }.padding(12)
            .background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(inUse(item) ? GardenTheme.accent : GardenTheme.border.opacity(0.4), lineWidth: inUse(item) ? 2 : 1))
    }

    private func inUse(_ item: ShopItem) -> Bool {
        switch item.category {
        case .accessory: session.preferences.accessory == item.accessory
        case .wall: session.pet.wall == item.id
        case .floor: session.pet.floor == item.id
        case .house: session.pet.house == item.id
        case .furniture: session.pet.room.values.contains(item.id)
        default: false
        }
    }
    private func useLabel(_ item: ShopItem) -> String? {
        switch item.category {
        case .accessory, .wall, .floor, .house: String(localized: "Usar")
        default: nil
        }
    }
    private func use(_ item: ShopItem) {
        if let accessory = item.accessory { session.wear(accessory) } else { session.use(item.id) }
    }
    private func buy(_ item: ShopItem) {
        switch session.buy(item.id) {
        case .none:
            switch item.category {
            case .furniture: note = String(localized: "\(item.title) comprado! Toque num espaço do quarto para colocar.")
            case .toy: note = String(localized: "\(item.title) já está no quarto. Toque nele para brincar.")
            case .wall, .floor, .house: session.use(item.id); note = String(localized: "\(item.title) já está em uso.")
            default: note = nil
            }
        case .notEnoughCoins?: note = String(localized: "Faltam moedas. Passeios rendem mais nos níveis difíceis.")
        case .alreadyOwned?: note = String(localized: "Você já tem isso.")
        case .unknownItem?: note = nil
        }
    }
}
