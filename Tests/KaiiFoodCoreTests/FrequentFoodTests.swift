import XCTest
@testable import KaiiFoodCore

final class FrequentFoodTests: XCTestCase {
    private var milk: FoodItem { FoodItem(name: "全脂牛奶", grams: 200, unit: "mL", nutrients: .init(kcal: 148, protein: 7.2, carbs: 10, fat: 8.8), source: "标签换算", uncertainty: "") }
    func testFixedPortionRoundTrip() throws {
        let value = FrequentFood(food: milk, portion: "1 盒")
        XCTAssertEqual(value, try JSONDecoder().decode(FrequentFood.self, from: JSONEncoder().encode(value)))
    }
    func testRepeatedAddsHaveIndependentIDsAndCorrectAmounts() throws {
        let value = FrequentFood(food: milk, portion: "1 盒")
        let first = try XCTUnwrap(value.item())
        let second = try XCTUnwrap(value.item(servings: 2))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.id, milk.id)
        XCTAssertEqual(first.unit, "mL")
        XCTAssertEqual(second.grams, 400)
        XCTAssertEqual(second.nutrients.protein, 14.4, accuracy: 0.001)
        XCTAssertEqual(value.food.grams, 200)
    }
    func testEditingTemplateLeavesRecordedFoodUnchanged() throws {
        var value = FrequentFood(food: milk, portion: "1 盒")
        let recorded = try XCTUnwrap(value.item())
        value.food = try XCTUnwrap(value.food.resized(toGrams: 300))
        XCTAssertEqual(recorded.grams, 200)
        XCTAssertEqual(recorded.nutrients.protein, 7.2)
    }
    func testInvalidPortionsRejected() {
        let value = FrequentFood(food: milk)
        for count in [0.0, -1, Double.nan, Double.infinity, 10000] { XCTAssertNil(value.item(servings: count)) }
        XCTAssertFalse(FrequentFood(food: milk, portion: " ").isValid)
    }
    func testLegacySettingsKeepChoiceAndReceiveKimiDefault() throws {
        let raw = Data(#"{"chatProvider":"deepseek","glmChatModel":"custom","visionModel":"vision","deepseekModel":"deepseek-flash"}"#.utf8)
        let value = try JSONDecoder().decode(AISettings.self, from: raw)
        XCTAssertEqual(value.chatProvider, .deepseek)
        XCTAssertEqual(value.glmChatModel, "custom")
        XCTAssertEqual(value.kimiModel, "kimi-k2.6")
        XCTAssertTrue(value.isValid)
    }
    func testProviderRoutesAndModels() {
        let settings = AISettings()
        XCTAssertEqual(settings.model(for: .kimi, photo: true), "kimi-k2.6")
        XCTAssertEqual(settings.model(for: .deepseek, photo: true), "deepseek-flash")
        XCTAssertEqual(AIProvider.kimi.endpoint.host, "api.moonshot.cn")
        XCTAssertFalse(AISettings(kimiModel: "bad model").isValid)
    }
}
