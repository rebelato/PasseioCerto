import Foundation

public enum ShopCategory: String, CaseIterable, Codable, Sendable {
    case food, accessory, furniture, toy, wall, floor, house
    public var title: String {
        switch self {
        case .food: String(localized: "Comida")
        case .accessory: String(localized: "Acessórios")
        case .furniture: String(localized: "Móveis")
        case .toy: String(localized: "Brinquedos")
        case .wall: String(localized: "Parede")
        case .floor: String(localized: "Piso")
        case .house: String(localized: "Casinha")
        }
    }
}

/// Where a piece of furniture can go in Margot's room.
public enum RoomSlot: String, CaseIterable, Codable, Sendable {
    case floorLeft, floorRight, wallLeft, wallRight, rug
    public var kind: FurnitureKind {
        switch self {
        case .floorLeft, .floorRight: .floor
        case .wallLeft, .wallRight: .wall
        case .rug: .rug
        }
    }
}
public enum FurnitureKind: String, Codable, Sendable { case floor, wall, rug }

/// One thing to buy. Ids are stable: they are stored in saves.
public struct ShopItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: ShopCategory
    public let price: Int
    public let title: String
    /// Food: how much hunger and joy one portion restores.
    public var hunger = 0
    public var joy = 0
    public var accessory: Accessory?
    public var furniture: FurnitureKind?
    /// Bought once and kept (everything except food).
    public var isConsumable: Bool { category == .food }
}

public enum ShopCatalog {
    public static let items: [ShopItem] = [
        ShopItem(id: "food.treat", category: .food, price: 10, title: String(localized: "Petisco"), hunger: 10, joy: 10),
        ShopItem(id: "food.kibble", category: .food, price: 15, title: String(localized: "Ração"), hunger: 30),
        ShopItem(id: "food.chicken", category: .food, price: 40, title: String(localized: "Frango"), hunger: 60, joy: 10),
        ShopItem(id: "food.cake", category: .food, price: 80, title: String(localized: "Bolo de patinha"), hunger: 40, joy: 40),

        ShopItem(id: "acc.bow", category: .accessory, price: 40, title: Accessory.bow.title, accessory: .bow),
        ShopItem(id: "acc.bandana", category: .accessory, price: 70, title: Accessory.bandana.title, accessory: .bandana),
        ShopItem(id: "acc.collar", category: .accessory, price: 90, title: Accessory.collar.title, accessory: .collar),
        ShopItem(id: "acc.hat", category: .accessory, price: 120, title: Accessory.hat.title, accessory: .hat),
        ShopItem(id: "acc.glasses", category: .accessory, price: 160, title: Accessory.glasses.title, accessory: .glasses),
        ShopItem(id: "acc.raincoat", category: .accessory, price: 200, title: Accessory.raincoat.title, accessory: .raincoat),

        ShopItem(id: "furn.cushion", category: .furniture, price: 60, title: String(localized: "Almofada"), furniture: .floor),
        ShopItem(id: "furn.plant", category: .furniture, price: 70, title: String(localized: "Planta"), furniture: .floor),
        ShopItem(id: "furn.rug", category: .furniture, price: 80, title: String(localized: "Tapete"), furniture: .rug),
        ShopItem(id: "furn.frame", category: .furniture, price: 90, title: String(localized: "Quadro da Margot"), furniture: .wall),
        ShopItem(id: "furn.lamp", category: .furniture, price: 100, title: String(localized: "Luminária"), furniture: .floor),
        ShopItem(id: "furn.clock", category: .furniture, price: 110, title: String(localized: "Relógio"), furniture: .wall),
        ShopItem(id: "furn.bed", category: .furniture, price: 120, title: String(localized: "Caminha"), furniture: .floor),
        ShopItem(id: "furn.shelf", category: .furniture, price: 150, title: String(localized: "Estante"), furniture: .floor),

        ShopItem(id: "toy.ball", category: .toy, price: 50, title: String(localized: "Bolinha")),
        ShopItem(id: "toy.bone", category: .toy, price: 70, title: String(localized: "Osso de brinquedo")),
        ShopItem(id: "toy.rope", category: .toy, price: 90, title: String(localized: "Cordinha")),

        ShopItem(id: "wall.cream", category: .wall, price: 0, title: String(localized: "Creme")),
        ShopItem(id: "wall.mint", category: .wall, price: 60, title: String(localized: "Menta")),
        ShopItem(id: "wall.peach", category: .wall, price: 60, title: String(localized: "Pêssego")),
        ShopItem(id: "wall.lavender", category: .wall, price: 80, title: String(localized: "Lavanda")),

        ShopItem(id: "floor.wood", category: .floor, price: 0, title: String(localized: "Madeira")),
        ShopItem(id: "floor.tiles", category: .floor, price: 70, title: String(localized: "Ladrilho")),
        ShopItem(id: "floor.grass", category: .floor, price: 90, title: String(localized: "Gramado")),

        ShopItem(id: "house.classic", category: .house, price: 0, title: String(localized: "Casinha clássica")),
        ShopItem(id: "house.cottage", category: .house, price: 250, title: String(localized: "Chalé")),
        ShopItem(id: "house.castle", category: .house, price: 500, title: String(localized: "Castelinho")),
    ]
    private static let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    public static func item(_ id: String) -> ShopItem? { byID[id] }
    public static func items(in category: ShopCategory) -> [ShopItem] { items.filter { $0.category == category } }
    public static func item(for accessory: Accessory) -> ShopItem { items.first { $0.accessory == accessory }! }
    /// What every Margot has from the start.
    public static let starterItems: Set<String> = ["wall.cream", "floor.wood", "house.classic"]
}

/// Coins for a finished walk.
public enum Rewards {
    public static func base(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 10
        case .medium: 25
        case .hard: 60
        case .expert: 120
        }
    }
    /// `base × paws`, but a replayed grid only pays the paws above its previous best, so the same
    /// walk can't be farmed. The daily challenge adds a bonus the first time, growing with the streak.
    public static func coins(difficulty: Difficulty, paws: Int, previousBest: Int, daily: Bool = false, streak: Int = 0) -> Int {
        let earned = base(difficulty) * max(0, paws - previousBest)
        let bonus = daily && previousBest == 0 ? 50 + min(100, 10 * max(0, streak)) : 0
        return earned + bonus
    }
    /// Joy from going out for a walk, whatever the score.
    public static let walkJoy = 15.0
}
