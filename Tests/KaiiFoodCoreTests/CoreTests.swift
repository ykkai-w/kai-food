import XCTest
@testable import KaiiFoodCore

final class CoreTests: XCTestCase {
    func testLocalizedExportPreservesUserText() {
        let date = Date(timeIntervalSince1970: 1788321600)
        let meal = MealEntry(date: date, kind: .lunch,
            items: [.init(name: "米饭", grams: 150, nutrients: .init(kcal: 174))],
            note: "妈妈做的", mealDescription: "米饭一碗")
        let words = ["午餐": "Lunch", "备注": "Notes", "餐食描述": "Meal description", "kaii 食记": "kaii Food"]
        let export = MealExport.markdown(entries: [meal], from: date, to: date, localize: { words[$0] ?? $0 })
        XCTAssertTrue(export.contains("# kaii Food"))
        XCTAssertTrue(export.contains("### Lunch"))
        XCTAssertTrue(export.contains("Notes 妈妈做的"))
        XCTAssertTrue(export.contains("Meal description 米饭一碗"))
        XCTAssertEqual(meal.items.first?.name, "米饭")
    }
    func testRecalledMealPersistsDateDescriptionAndExportWithoutPhoto() throws {
        let date = Date(timeIntervalSince1970: 1788321600)
        let meal = MealEntry(date: date, kind: .lunch, items: [.init(name: "米饭", grams: 150, nutrients: .init(kcal: 174))], mealDescription: "米饭一碗|青菜半盘")
        let stored = try JSONDecoder().decode(MealEntry.self, from: JSONEncoder().encode(meal))
        XCTAssertEqual(stored, meal)
        XCTAssertNil(stored.photoFilename)
        let export = MealExport.markdown(entries: [stored], from: date, to: date)
        XCTAssertTrue(export.contains("餐食描述 米饭一碗\\|青菜半盘"))
        XCTAssertTrue(MealExport.csv(entries: [stored], from: date, to: date).contains("米饭一碗|青菜半盘"))
    }

    func testOldMealStillDecodesWithoutDescription() throws {
        let meal = MealEntry(kind: .dinner, items: [], note: "旧备注")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(meal)) as? [String: Any])
        json.removeValue(forKey: "mealDescription")
        let restored = try JSONDecoder().decode(MealEntry.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.mealDescription)
        XCTAssertEqual(restored.note, "旧备注")
    }

    func testInputMethodsHaveIndependentRequirements() {
        XCTAssertTrue(MealInputMethod.description.canAnalyze(hasPhoto: false, description: "鸡腿一个", labelText: ""))
        XCTAssertFalse(MealInputMethod.description.canAnalyze(hasPhoto: true, description: " \n ", labelText: ""))
        XCTAssertFalse(MealInputMethod.photo.canAnalyze(hasPhoto: false, description: "鸡腿一个", labelText: ""))
        XCTAssertTrue(MealInputMethod.photo.canAnalyze(hasPhoto: true, description: "", labelText: ""))
        XCTAssertFalse(MealInputMethod.label.canAnalyze(hasPhoto: true, description: "200mL", labelText: ""))
        XCTAssertTrue(MealInputMethod.label.canAnalyze(hasPhoto: false, description: "200mL", labelText: "每100mL蛋白质3.6g"))
    }

    private let goodJSON = #"{"items":[{"name":"鸡胸肉","grams":150,"kcal":248,"protein":46,"carbs":0,"fat":5,"source":"AI估算","uncertainty":"估计120–180克，可能有烹调油"}]}"#

    func testWholePortionTotalsAndResize() throws {
        let items = try NutritionParser.parse(goodJSON)
        XCTAssertEqual(items[0].nutrients.protein, 46)
        let double = try XCTUnwrap(items[0].resized(toGrams: 300))
        XCTAssertEqual(double.nutrients.kcal, 496)
        let meal = MealEntry(kind: .lunch, items: [items[0], double])
        XCTAssertEqual(meal.total.protein, 138)
        XCTAssertNil(items[0].resized(toGrams: -20))
        XCTAssertNil(items[0].resized(toGrams: .nan))
    }

    func testLabelConversions() {
        let milk = Nutrients.per100(kcal: Nutrients.kcal(fromKilojoules: 309), protein: 3.6, carbs: 5, fat: 4.4, grams: 200)
        XCTAssertEqual(milk.protein, 7.2)
        XCTAssertEqual(milk.kcal, 147.7055, accuracy: 0.001)
        XCTAssertEqual(milk.fat, 8.8)
    }

    func testFencedJSONAccepted() throws {
        XCTAssertEqual(try NutritionParser.parse("```json\n" + goodJSON + "\n```").count, 1)
    }

    func testAIReadLabelIsNotPresentedAsManualVerifiedLabel() throws {
        let draft = try NutritionParser.parse(goodJSON.replacingOccurrences(of: "AI估算", with: "标签换算"))
        XCTAssertEqual(draft.first?.source, "AI标签换算（待核对）")
    }

    func testExportRangeBound() {
        let now = Date()
        let longRange = Calendar.current.date(byAdding: .day, value: 366, to: now)!
        XCTAssertTrue(MealExport.markdown(entries: [], from: now, to: longRange).contains("最多导出 366"))
        XCTAssertTrue(MealExport.csv(entries: [], from: now, to: longRange).contains("最多导出 366"))
    }

    func testMissingNumbersNeverSilentlyBecomeZero() {
        XCTAssertThrowsError(try NutritionParser.parse(#"{"items":[{"name":"饭","grams":100,"kcal":100,"protein":1,"carbs":20,"source":"AI估算","uncertainty":"份量未知"}]}"#))
    }

    func testStringNumberRejected() {
        XCTAssertThrowsError(try NutritionParser.parse(goodJSON.replacingOccurrences(of: "\"grams\":150", with: "\"grams\":\"150\"")))
    }

    func testLiquidUnitsPersistAndExport() throws {
        let liquidJSON = goodJSON.replacingOccurrences(of: "\"grams\":150", with: "\"grams\":150,\"unit\":\"mL\"")
        let items = try NutritionParser.parse(liquidJSON)
        XCTAssertEqual(items.first?.unit, "mL")
        let now = Date()
        XCTAssertTrue(MealExport.markdown(entries: [.init(kind: .snack, items: items)], from: now, to: now).contains("150.0 mL"))
        let encoded = try JSONEncoder().encode(items[0])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "unit")
        let old = try JSONDecoder().decode(FoodItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(old.unit, "g")
    }

    func testNegativeAndUnreasonableValuesRejected() {
        XCTAssertThrowsError(try NutritionParser.parse(goodJSON.replacingOccurrences(of: "\"kcal\":248", with: "\"kcal\":-248")))
        XCTAssertThrowsError(try NutritionParser.parse(goodJSON.replacingOccurrences(of: "\"protein\":46", with: "\"protein\":9999")))
        XCTAssertThrowsError(try NutritionParser.parse(goodJSON.replacingOccurrences(of: "\"grams\":150", with: "\"grams\":0")))
        XCTAssertThrowsError(try NutritionParser.parse(goodJSON.replacingOccurrences(of: "\"grams\":150", with: "\"grams\":1e999")))
    }

    func testUnknownSourceAndEmptyUncertaintyRejected() {
        XCTAssertThrowsError(try NutritionParser.parse(goodJSON.replacingOccurrences(of: "AI估算", with: "精确测量")))
        XCTAssertThrowsError(try NutritionParser.parse(goodJSON.replacingOccurrences(of: "估计120–180克，可能有烹调油", with: "")))
        XCTAssertThrowsError(try NutritionParser.parse(#"{"items":[]}"#))
    }

    func testExtraTextOrTruncatedJSONRejected() {
        XCTAssertThrowsError(try NutritionParser.parse("这里是分析：" + goodJSON))
        XCTAssertThrowsError(try NutritionParser.parse(String(goodJSON.dropLast())))
    }

    func testCodableRoundTripNoCredentials() throws {
        let settings = AISettings()
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AISettings.self, from: data), settings)
        let text = String(decoding: data, as: UTF8.self).lowercased()
        XCTAssertFalse(text.contains("apikey"))
        let entry = MealEntry(kind: .dinner, items: try NutritionParser.parse(goodJSON), note: "今天在食堂", photoFilename: "meal.jpg")
        XCTAssertEqual(try JSONDecoder().decode(MealEntry.self, from: JSONEncoder().encode(entry)), entry)
    }

    func testLocalCalendarInclusiveDaysAndUnrecordedMeals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let formatter = ISO8601DateFormatter()
        let from = formatter.date(from: "2026-09-02T12:00:00+08:00")!
        let to = formatter.date(from: "2026-09-03T12:00:00+08:00")!
        let food = FoodItem(name: "面包", grams: 50, nutrients: .init(kcal: 100, protein: 4, carbs: 20, fat: 1))
        let inside = MealEntry(date: formatter.date(from: "2026-09-03T23:59:59+08:00")!, kind: .snack, items: [food])
        let outside = MealEntry(date: formatter.date(from: "2026-09-04T00:00:00+08:00")!, kind: .lunch, items: [FoodItem(name: "不应出现", grams: 1, nutrients: .init())])
        let result = MealExport.markdown(entries: [inside, outside], from: from, to: to, calendar: calendar)
        XCTAssertTrue(result.contains("2026-09-02"))
        XCTAssertTrue(result.contains("2026-09-03"))
        XCTAssertTrue(result.hasPrefix("# kaii 食记\n"))
        XCTAssertTrue(result.contains("2026-09-02 至 2026-09-03"))
        XCTAssertTrue(result.contains("早餐 · 未记录"))
        XCTAssertTrue(result.contains("已记录合计 100.0 千卡"))
        XCTAssertFalse(result.contains("非全天摄入"))
        XCTAssertFalse(result.contains("不代表"))
        XCTAssertTrue(result.contains("面包"))
        XCTAssertFalse(result.contains("不应出现"))
        let emptyDay = result.components(separatedBy: "## 2026-09-03")[0]
        XCTAssertFalse(emptyDay.contains("千卡"))
        XCTAssertFalse(emptyDay.contains("已记录合计"))
    }

    func testExportEscapesFieldsAndShowsPhotoLocation() {
        let food = FoodItem(name: "鸡|鱼\n菜", grams: 100, nutrients: .init(kcal: 100), uncertainty: "<script>\n|估计")
        let now = Date()
        let meal = MealEntry(date: now, kind: .lunch, items: [food], note: "A|B\nC", photoFilename: "photo.jpg")
        let result = MealExport.markdown(entries: [meal], from: now, to: now)
        XCTAssertTrue(result.contains("鸡\\|鱼 菜"))
        XCTAssertTrue(result.contains("&lt;script&gt;"))
        XCTAssertTrue(result.contains("A\\|B C"))
        XCTAssertTrue(result.contains("照片保存在 App 内。"))
    }

    func testCSVQuotesAndNeutralizesFormula() {
        let now = Date()
        let food = FoodItem(name: "=HYPERLINK(\"x\")", grams: 10, nutrients: .init(kcal: 5))
        let result = MealExport.csv(entries: [.init(date: now, kind: .snack, items: [food])], from: now, to: now)
        XCTAssertTrue(result.contains("\"'=HYPERLINK(\"\"x\"\")\""))
        XCTAssertTrue(result.contains("\"来源\",\"估算说明\",\"备注\""))
        XCTAssertFalse(result.contains("非全天摄入"))
    }

    func testEmptyExportsDoNotInventZeroIntake() {
        let now = Date()
        let markdown = MealExport.markdown(entries: [], from: now, to: now)
        for kind in MealKind.allCases {
            XCTAssertTrue(markdown.contains("### \(kind.displayName) · 未记录"))
        }
        XCTAssertFalse(markdown.contains("0.0"))
        XCTAssertFalse(markdown.contains("已记录合计"))
        let csv = MealExport.csv(entries: [], from: now, to: now)
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 1)
        XCTAssertFalse(csv.contains("0.0"))
    }

    func testExportKeepsSourceUnitsAndUnavailableValues() {
        let now = Date()
        let food = FoodItem(name: "牛奶", grams: 200, unit: "mL", nutrients: .init(kcal: .nan, protein: 7.2, carbs: 10, fat: 8.8), source: "标签换算", uncertainty: "按包装每 100 mL 换算")
        let meal = MealEntry(date: now, kind: .breakfast, items: [food])
        let markdown = MealExport.markdown(entries: [meal], from: now, to: now)
        XCTAssertTrue(markdown.contains("200.0 mL | 未知 | 7.2 | 10.0 | 8.8 | 标签换算 | 按包装每 100 mL 换算"))
        XCTAssertTrue(markdown.contains("已记录合计 未知 千卡"))
        let csv = MealExport.csv(entries: [meal], from: now, to: now)
        XCTAssertTrue(csv.contains("\"200.0\",\"mL\",\"未知\",\"7.2\""))
        XCTAssertTrue(csv.contains("标签换算"))
        XCTAssertTrue(csv.contains("按包装每 100 mL 换算"))
    }

    func testCSVFiltersInclusiveLocalDateRange() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: start)!
        func entry(_ date: Date, _ name: String) -> MealEntry {
            .init(date: date, kind: .lunch, items: [.init(name: name, grams: 50, nutrients: .init(kcal: 100))])
        }
        let csv = MealExport.csv(entries: [entry(yesterday, "日期之前"), entry(start, "当日零点"), entry(tomorrow.addingTimeInterval(-1), "当日末尾"), entry(tomorrow, "日期之后")], from: start, to: start)
        XCTAssertTrue(csv.contains("当日零点"))
        XCTAssertTrue(csv.contains("当日末尾"))
        XCTAssertFalse(csv.contains("日期之前"))
        XCTAssertFalse(csv.contains("日期之后"))
    }

    func testInvalidDateRange() {
        XCTAssertEqual(MealExport.markdown(entries: [], from: Date(timeIntervalSince1970: 200000), to: Date(timeIntervalSince1970: 0)), "日期范围无效。")
    }
}
