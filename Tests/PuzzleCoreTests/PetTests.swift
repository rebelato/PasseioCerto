import XCTest
@testable import PuzzleCore
final class PetTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private func hours(_ h: Double) -> Date { start.addingTimeInterval(h * 3600) }

    func testNeedsFallWithTimeButNeverBelowZeroOrBackwards() {
        var pet = PetState(hunger: 100, joy: 100, now: start)
        pet.advance(to: hours(24))
        XCTAssertEqual(pet.hunger, 50, accuracy: 0.01)
        XCTAssertEqual(pet.joy, 100 - 24 * 100 / 36, accuracy: 0.01)
        let before = pet
        pet.advance(to: hours(10))
        XCTAssertEqual(pet, before, "A clock that went back changes nothing")
        pet.advance(to: hours(500))
        XCTAssertEqual(pet.hunger, 0); XCTAssertEqual(pet.joy, 0)
        XCTAssertEqual(pet.mood, .hungry, "Hungry and bored is just a sad face: nothing worse happens")
    }
    func testTimeUntilHungry() {
        let pet = PetState(hunger: 80, joy: 80, now: start)
        XCTAssertEqual(pet.timeUntilHungry(from: start)!, 24 * 3600, accuracy: 1, "From 80 to 30 is half of the 48 hours")
        XCTAssertEqual(pet.timeUntilHungry(from: hours(6))!, 18 * 3600, accuracy: 1)
        XCTAssertNil(PetState(hunger: 20, joy: 80, now: start).timeUntilHungry(from: start))
    }
    func testMoodFollowsNeeds() {
        XCTAssertEqual(PetState(hunger: 80, joy: 80).mood, .happy)
        XCTAssertEqual(PetState(hunger: 50, joy: 80).mood, .okay)
        XCTAssertEqual(PetState(hunger: 80, joy: 20).mood, .sad)
        XCTAssertEqual(PetState(hunger: 20, joy: 20).mood, .hungry)
    }
    func testBuyingFeedingAndOwning() throws {
        var pet = PetState(coins: 100, hunger: 20, joy: 50, now: start)
        XCTAssertEqual(pet.portions(of: "food.kibble"), 2, "Every Margot starts with a little food")
        try pet.buy("food.chicken")
        XCTAssertEqual(pet.coins, 60)
        XCTAssertTrue(pet.feed("food.chicken", now: start))
        XCTAssertEqual(pet.hunger, 80); XCTAssertEqual(pet.joy, 60)
        XCTAssertFalse(pet.feed("food.chicken", now: start), "No portion left")
        XCTAssertThrowsError(try pet.buy("furn.shelf")) { XCTAssertEqual($0 as? PetState.PurchaseError, .notEnoughCoins) }
        try pet.buy("acc.bow")
        XCTAssertThrowsError(try pet.buy("acc.bow")) { XCTAssertEqual($0 as? PetState.PurchaseError, .alreadyOwned) }
        XCTAssertThrowsError(try pet.buy("nope")) { XCTAssertEqual($0 as? PetState.PurchaseError, .unknownItem) }
        XCTAssertEqual(pet.coins, 20)
    }
    func testToysPettingAndDecorating() throws {
        var pet = PetState(coins: 600, hunger: 80, joy: 50, now: start)
        XCTAssertFalse(pet.play(with: "toy.ball", now: start), "Only owned toys")
        try pet.buy("toy.ball")
        XCTAssertTrue(pet.play(with: "toy.ball", now: start))
        XCTAssertEqual(pet.joy, 60)
        XCTAssertFalse(pet.play(with: "toy.ball", now: hours(0.5)), "One hour between games")
        XCTAssertEqual(pet.toyCooldownLeft("toy.ball", now: hours(0.5)), 1800, accuracy: 1)
        XCTAssertTrue(pet.play(with: "toy.ball", now: hours(1.01)))
        XCTAssertTrue(pet.pet(now: hours(2)))
        XCTAssertFalse(pet.pet(now: hours(2).addingTimeInterval(5)))
        try pet.buy("furn.frame"); try pet.buy("furn.bed")
        XCTAssertFalse(pet.place("furn.frame", in: .floorLeft), "A frame goes on the wall")
        XCTAssertTrue(pet.place("furn.bed", in: .floorLeft))
        XCTAssertTrue(pet.place("furn.bed", in: .floorRight))
        XCTAssertEqual(pet.room, [.floorRight: "furn.bed"], "An item sits in one slot at a time")
        XCTAssertFalse(pet.use("house.castle"))
        try pet.buy("house.cottage")
        XCTAssertTrue(pet.use("house.cottage")); XCTAssertEqual(pet.house, "house.cottage")
    }
    func testRewardsScaleWithDifficultyAndCannotBeFarmed() {
        XCTAssertEqual(Rewards.coins(difficulty: .easy, paws: 3, previousBest: 0), 30)
        XCTAssertEqual(Rewards.coins(difficulty: .expert, paws: 2, previousBest: 0), 240)
        XCTAssertEqual(Rewards.coins(difficulty: .hard, paws: 3, previousBest: 2), 60, "Replays only pay the improvement")
        XCTAssertEqual(Rewards.coins(difficulty: .hard, paws: 2, previousBest: 3), 0)
        XCTAssertEqual(Rewards.coins(difficulty: .medium, paws: 3, previousBest: 0, daily: true, streak: 4), 75 + 50 + 40)
        XCTAssertEqual(Rewards.coins(difficulty: .medium, paws: 1, previousBest: 0, daily: true, streak: 30), 25 + 150, "Streak bonus is capped")
    }
    func testPetRoundTripsAndDropsUnknownItems() throws {
        var pet = PetState(coins: 300, now: start)
        try pet.buy("furn.rug"); pet.place("furn.rug", in: .rug); try pet.buy("food.cake")
        let data = try JSONEncoder().encode(pet)
        XCTAssertEqual(try JSONDecoder().decode(PetState.self, from: data), pet)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["owned"] = ["furn.rug", "future.item"]
        json["wall"] = "wall.lavender"
        let loaded = try JSONDecoder().decode(PetState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(loaded.owns("future.item"))
        XCTAssertEqual(loaded.wall, "wall.cream", "Colours that aren't owned fall back to the default")
    }

    // MARK: Session

    @MainActor func testFinishedWalkPaysCoinsAndJoyOnce() async {
        let s = GameSession(attempt: GameAttempt(difficulty: .medium))
        let coins = s.pet.coins, joy = s.pet.joy
        await s.select(Cell(1,0), marking: false) // one mistake: 2 paws
        for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() { await s.select(cell, marking: false) }
        XCTAssertEqual(s.lastReward, WalkReward(coins: 50, joy: 15))
        XCTAssertEqual(s.pet.coins, coins + 50)
        XCTAssertEqual(s.pet.joy, min(100, joy + 15), accuracy: 0.5)
        s.restart()
        XCTAssertNil(s.lastReward)
        for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() { await s.select(cell, marking: false) }
        XCTAssertEqual(s.lastReward?.coins, 25, "Replaying pays only the extra paw")
    }
    @MainActor func testShoppingFromTheSessionPersistsAndWearsAccessories() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let s = GameSession(saveURL: url)
        XCTAssertEqual(s.buy("acc.raincoat"), .notEnoughCoins)
        XCTAssertNil(s.buy("acc.bow"))
        XCTAssertEqual(s.preferences.accessory, .bow, "A bought accessory is worn right away")
        XCTAssertTrue(s.feed("food.kibble"))
        let restored = GameSession(saveURL: url)
        XCTAssertTrue(restored.pet.owns("acc.bow"))
        XCTAssertEqual(restored.pet.portions(of: "food.kibble"), 1)
        XCTAssertEqual(restored.ownedAccessories, [.bow])
    }
    @MainActor func testTimePassesForTheSessionPet() {
        nonisolated(unsafe) var now = start
        let s = GameSession(clock: { now })
        let hunger = s.pet.hunger
        now = hours(12)
        s.refreshPet()
        XCTAssertEqual(s.pet.hunger, hunger - 25, accuracy: 0.01)
    }
    func testV6SavesKeepUnlockedAccessoriesAndGetCoins() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(PlayerSave(bestPaws: ["a": 3, "b": 3, "c": 3, "d": 3]))) as? [String: Any])
        json["schemaVersion"] = 6
        json.removeValue(forKey: "pet")
        var preferences = try XCTUnwrap(json["preferences"] as? [String: Any])
        preferences["accessory"] = "hat"
        json["preferences"] = preferences
        let save = try JSONDecoder().decode(PlayerSave.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(save.schemaVersion, 7)
        XCTAssertEqual(save.pet.coins, 50 + 5 * 12)
        XCTAssertTrue(save.pet.owns("acc.bow"), "12 paws had unlocked the bow")
        XCTAssertFalse(save.pet.owns("acc.bandana"))
        XCTAssertNil(save.preferences.accessory, "A hat that was never unlocked can't stay on")
    }
}
