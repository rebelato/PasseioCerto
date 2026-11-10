import Foundation

public enum PetMood: String, Sendable {
    case happy, okay, sad, hungry
}

/// Margot as a virtual pet. Hunger and joy fall slowly with real time, but nothing bad ever
/// happens: a hungry or bored Margot just looks a bit down and asks for food or a walk.
public struct PetState: Codable, Equatable, Sendable {
    public static let hoursToHungry = 48.0
    public static let hoursToBored = 36.0
    public static let toyCooldown: TimeInterval = 3600
    public static let petCooldown: TimeInterval = 20

    public private(set) var hunger: Double
    public private(set) var joy: Double
    public private(set) var coins: Int
    public private(set) var lastUpdate: Date
    /// Food portions waiting in the pantry.
    public private(set) var inventory: [String: Int]
    /// Everything bought for keeps (accessories, furniture, toys, colours, houses).
    public private(set) var owned: Set<String>
    /// Furniture placed in the room, by slot.
    public private(set) var room: [RoomSlot: String]
    public private(set) var wall: String
    public private(set) var floor: String
    public private(set) var house: String
    public private(set) var toyPlayedAt: [String: Date]
    public private(set) var pettedAt: Date?

    public init(coins: Int = 50, hunger: Double = 80, joy: Double = 80, now: Date = Date(), owned: Set<String> = []) {
        self.hunger = hunger; self.joy = joy; self.coins = coins; lastUpdate = now
        inventory = ["food.kibble": 2, "food.treat": 1]
        self.owned = owned.union(ShopCatalog.starterItems)
        room = [:]; wall = "wall.cream"; floor = "floor.wood"; house = "house.classic"
        toyPlayedAt = [:]; pettedAt = nil
    }

    /// The starting state for players who had the game before the pet: accessories they had
    /// unlocked with paws stay theirs, and their past walks become a small purse.
    public static func migrated(totalPaws: Int, now: Date = Date()) -> PetState {
        let accessories = Accessory.allCases.filter { $0.legacyPawCost <= totalPaws }.map { ShopCatalog.item(for: $0).id }
        return PetState(coins: 50 + 5 * totalPaws, now: now, owned: Set(accessories))
    }

    // MARK: Time

    /// Applies the slow fall of hunger and joy since the last update. A clock that went back is ignored.
    public mutating func advance(to now: Date) {
        let hours = now.timeIntervalSince(lastUpdate) / 3600
        guard hours > 0 else { return }
        hunger = max(0, hunger - hours * 100 / Self.hoursToHungry)
        joy = max(0, joy - hours * 100 / Self.hoursToBored)
        lastUpdate = now
    }
    /// Time until hunger falls to the "hungry" line (30), or nil if she is already hungry.
    public func timeUntilHungry(from now: Date) -> TimeInterval? {
        var current = self; current.advance(to: now)
        guard current.hunger > 30 else { return nil }
        return (current.hunger - 30) / 100 * Self.hoursToHungry * 3600
    }
    public var mood: PetMood {
        if hunger < 30 { return .hungry }
        if joy < 30 { return .sad }
        return hunger >= 60 && joy >= 60 ? .happy : .okay
    }
    /// What Margot says in her speech bubble.
    public var speech: String {
        switch mood {
        case .hungry: String(localized: "Tô com fominha… tem petisco?")
        case .sad: String(localized: "Bora passear? Tô entediada.")
        case .okay: String(localized: "Que tal um passeio?")
        case .happy: String(localized: "Que dia bom! Obrigada por cuidar de mim.")
        }
    }

    // MARK: Spending

    public enum PurchaseError: Error, Equatable { case unknownItem, notEnoughCoins, alreadyOwned }
    public mutating func buy(_ id: String) throws(PurchaseError) {
        guard let item = ShopCatalog.item(id) else { throw .unknownItem }
        guard item.isConsumable || !owned.contains(id) else { throw .alreadyOwned }
        guard coins >= item.price else { throw .notEnoughCoins }
        coins -= item.price
        if item.isConsumable { inventory[id, default: 0] += 1 } else { owned.insert(id) }
    }
    public func owns(_ id: String) -> Bool { owned.contains(id) }
    public func portions(of id: String) -> Int { inventory[id] ?? 0 }

    // MARK: Care

    /// Eats one portion from the pantry. Returns false when there is none.
    @discardableResult public mutating func feed(_ id: String, now: Date = Date()) -> Bool {
        guard let item = ShopCatalog.item(id), item.category == .food, portions(of: id) > 0 else { return false }
        advance(to: now)
        inventory[id] = portions(of: id) - 1
        if inventory[id] == 0 { inventory[id] = nil }
        hunger = min(100, hunger + Double(item.hunger))
        joy = min(100, joy + Double(item.joy))
        return true
    }
    public func canPlay(with toy: String, now: Date = Date()) -> Bool {
        owned.contains(toy) && toyCooldownLeft(toy, now: now) == 0
    }
    /// Seconds until a toy can be played with again.
    public func toyCooldownLeft(_ toy: String, now: Date = Date()) -> TimeInterval {
        guard let last = toyPlayedAt[toy], now >= last else { return 0 }
        return max(0, Self.toyCooldown - now.timeIntervalSince(last))
    }
    @discardableResult public mutating func play(with toy: String, now: Date = Date()) -> Bool {
        guard ShopCatalog.item(toy)?.category == .toy, canPlay(with: toy, now: now) else { return false }
        advance(to: now)
        toyPlayedAt[toy] = now
        joy = min(100, joy + 10)
        return true
    }
    /// A pat on the head: a little joy, not more often than every few seconds.
    @discardableResult public mutating func pet(now: Date = Date()) -> Bool {
        if let last = pettedAt, now >= last, now.timeIntervalSince(last) < Self.petCooldown { return false }
        advance(to: now)
        pettedAt = now
        joy = min(100, joy + 2)
        return true
    }
    /// A finished walk: coins and a happier dog.
    public mutating func walked(coins earned: Int, now: Date = Date()) {
        advance(to: now)
        coins += max(0, earned)
        joy = min(100, joy + Rewards.walkJoy)
    }

    // MARK: Decorating

    /// Puts an owned piece of furniture in a slot that fits it (nil empties the slot). Returns false otherwise.
    @discardableResult public mutating func place(_ id: String?, in slot: RoomSlot) -> Bool {
        guard let id else { room[slot] = nil; return true }
        guard owned.contains(id), ShopCatalog.item(id)?.furniture == slot.kind else { return false }
        for (other, placed) in room where placed == id { room[other] = nil }
        room[slot] = id
        return true
    }
    /// Uses an owned wall colour, floor or house model.
    @discardableResult public mutating func use(_ id: String) -> Bool {
        guard owned.contains(id), let item = ShopCatalog.item(id) else { return false }
        switch item.category {
        case .wall: wall = id
        case .floor: floor = id
        case .house: house = id
        default: return false
        }
        return true
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey { case hunger, joy, coins, lastUpdate, inventory, owned, room, wall, floor, house, toyPlayedAt, pettedAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hunger = min(100, max(0, try c.decode(Double.self, forKey: .hunger)))
        joy = min(100, max(0, try c.decode(Double.self, forKey: .joy)))
        coins = max(0, try c.decode(Int.self, forKey: .coins))
        lastUpdate = try c.decode(Date.self, forKey: .lastUpdate)
        // Unknown ids (from a newer catalog) are dropped rather than breaking the save.
        inventory = (try c.decode([String: Int].self, forKey: .inventory)).filter { ShopCatalog.item($0.key) != nil && $0.value > 0 }
        owned = Set(try c.decode([String].self, forKey: .owned)).filter { ShopCatalog.item($0) != nil }.union(ShopCatalog.starterItems)
        let slots = try c.decode([String: String].self, forKey: .room)
        room = Dictionary(uniqueKeysWithValues: slots.compactMap { key, value in RoomSlot(rawValue: key).map { ($0, value) } })
            .filter { slot, id in ShopCatalog.item(id)?.furniture == slot.kind }
        wall = try c.decode(String.self, forKey: .wall)
        floor = try c.decode(String.self, forKey: .floor)
        house = try c.decode(String.self, forKey: .house)
        toyPlayedAt = try c.decodeIfPresent([String: Date].self, forKey: .toyPlayedAt) ?? [:]
        pettedAt = try c.decodeIfPresent(Date.self, forKey: .pettedAt)
        if !owned.contains(wall) { wall = "wall.cream" }
        if !owned.contains(floor) { floor = "floor.wood" }
        if !owned.contains(house) { house = "house.classic" }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hunger, forKey: .hunger); try c.encode(joy, forKey: .joy); try c.encode(coins, forKey: .coins)
        try c.encode(lastUpdate, forKey: .lastUpdate); try c.encode(inventory, forKey: .inventory)
        try c.encode(owned.sorted(), forKey: .owned)
        try c.encode(Dictionary(uniqueKeysWithValues: room.map { ($0.key.rawValue, $0.value) }), forKey: .room)
        try c.encode(wall, forKey: .wall); try c.encode(floor, forKey: .floor); try c.encode(house, forKey: .house)
        try c.encode(toyPlayedAt, forKey: .toyPlayedAt); try c.encodeIfPresent(pettedAt, forKey: .pettedAt)
    }
}
