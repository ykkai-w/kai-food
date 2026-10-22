import Foundation
import KaiiFoodCore

// Run with `swift run KaiiFoodCoreCheck` on Macs that have CLT but not Xcode/XCTest.
private final class MockProtocol: URLProtocol {
    static var status = 200
    static var response = Data()
    static var captured: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.captured = request
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: [:])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.response)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct CoreCheck {
    static func main() async throws {
        var checks = 0
        func check(_ value: Bool, _ name: String) throws {
            guard value else { throw NSError(domain: "CoreCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "FAIL: " + name]) }
            checks += 1
            print("PASS \(name)")
        }
        func rejects(_ json: String) -> Bool {
            do { _ = try NutritionParser.parse(json); return false } catch { return true }
        }
        let good = #"{"items":[{"name":"鸡胸肉","grams":150,"kcal":248,"protein":46,"carbs":0,"fat":5,"source":"AI估算","uncertainty":"份量和用油待确认"}]}"#
        let food = try NutritionParser.parse(good)[0]
        try check(food.nutrients.protein == 46, "whole-portion parsing")
        try check(try NutritionParser.parse("```json\n" + good + "\n```").count == 1, "fenced JSON")
        try check(rejects(good.replacingOccurrences(of: ",\"fat\":5", with: "")), "missing nutrient rejected")
        try check(rejects(good.replacingOccurrences(of: "\"grams\":150", with: "\"grams\":\"150\"")), "string number rejected")
        try check(rejects(good.replacingOccurrences(of: "\"kcal\":248", with: "\"kcal\":-1")), "negative rejected")
        try check(rejects(good.replacingOccurrences(of: "\"grams\":150", with: "\"grams\":1e999")), "nonfinite rejected")
        try check(rejects(good.replacingOccurrences(of: "\"protein\":46", with: "\"protein\":9999")), "implausible nutrient rejected")
        try check(rejects(good.replacingOccurrences(of: "AI估算", with: "精确测量")), "unknown source rejected")
        try check(rejects(good.replacingOccurrences(of: "份量和用油待确认", with: "")), "missing uncertainty rejected")
        try check(rejects(#"{"items":[]}"#), "empty AI draft rejected")
        try check(rejects(String(good.dropLast())), "truncated JSON rejected")
        let aiLabel = try NutritionParser.parse(good.replacingOccurrences(of: "AI估算", with: "标签换算"))[0]
        try check(aiLabel.source == "AI标签换算（待核对）", "AI label provenance explicit")
        try check(food.resized(toGrams: 300)?.nutrients.protein == 92, "portion resizing")
        try check(food.resized(toGrams: -1) == nil, "invalid resize rejected")
        try check(MealEntry(kind: .lunch, items: [food, food]).total.kcal == 496, "meal total")
        let milk = Nutrients.per100(kcal: Nutrients.kcal(fromKilojoules: 309), protein: 3.6, carbs: 5, fat: 4.4, grams: 200)
        try check(abs(milk.kcal - 147.7055) < 0.001 && milk.protein == 7.2, "kJ and per100 conversion")
        let liquid = try NutritionParser.parse(good.replacingOccurrences(of: "\"grams\":150", with: "\"grams\":150,\"unit\":\"mL\""))[0]
        try check(liquid.unit == "mL", "liquid unit")
        var encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(liquid)) as! [String: Any]
        encoded.removeValue(forKey: "unit")
        let old = try JSONDecoder().decode(FoodItem.self, from: JSONSerialization.data(withJSONObject: encoded))
        try check(old.unit == "g", "legacy unit decoding")
        let settings = AISettings()
        let data = try JSONEncoder().encode(settings)
        try check(try JSONDecoder().decode(AISettings.self, from: data) == settings, "settings round trip")
        try check(!String(decoding: data, as: UTF8.self).lowercased().contains("apikey"), "no keys in settings")
        let iso = ISO8601DateFormatter()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 28800)!
        let date = iso.date(from: "2026-09-02T12:00:00+08:00")!
        let last = iso.date(from: "2026-09-03T12:00:00+08:00")!
        let late = MealEntry(date: iso.date(from: "2026-09-03T23:59:59+08:00")!, kind: .snack, items: [liquid])
        let outside = MealEntry(date: iso.date(from: "2026-09-04T00:00:00+08:00")!, kind: .lunch, items: [.init(name: "OUTSIDE", grams: 1, nutrients: .init())])
        let md = MealExport.markdown(entries: [late, outside], from: date, to: last, calendar: cal)
        try check(md.contains("150.0 mL") && !md.contains("OUTSIDE"), "inclusive local date range")
        try check(md.contains("早餐 · 未记录"), "missing meals stay unrecorded")
        try check(md.contains("已记录合计") && !md.contains("非全天摄入"), "concise recorded totals")
        try check(md.hasPrefix("# kaii 食记\n") && md.contains("2026-09-02 至 2026-09-03"), "concise export heading and range")
        let empty = MealExport.markdown(entries: [], from: date, to: date, calendar: cal)
        try check(empty.contains("未记录") && !empty.contains("0.0") && !empty.contains("已记录合计"), "empty day has no fabricated totals")
        let now = Date()
        let evil = FoodItem(name: "=鸡|鱼\n<饭>", grams: 10, nutrients: .init(kcal: 5))
        let entry = MealEntry(date: now, kind: .lunch, items: [evil], photoFilename: "a.jpg")
        let escaped = MealExport.markdown(entries: [entry], from: now, to: now)
        try check(escaped.contains("鸡\\|鱼 &lt;饭&gt;"), "Markdown escaping")
        try check(escaped.contains("照片保存在 App 内。"), "photo location")
        try check(MealExport.csv(entries: [entry], from: now, to: now).contains("\"'=鸡"), "CSV formula neutralization")
        try check(MealExport.markdown(entries: [], from: last, to: date) == "日期范围无效。", "invalid range")
        let longRange = Calendar.current.date(byAdding: .day, value: 366, to: now)!
        try check(MealExport.markdown(entries: [], from: now, to: longRange).contains("最多导出 366"), "Markdown range bounded")
        try check(MealExport.csv(entries: [], from: now, to: longRange).contains("最多导出 366"), "CSV range bounded")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        let client = AIClient(session: URLSession(configuration: config))
        func envelope(_ value: String, finish: String = "stop") throws -> Data {
            try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": value], "finish_reason": finish]]])
        }
        MockProtocol.response = try envelope(good)
        let parsed = try await client.analyze(photoJPEG: Data([1,2,3]), description: "午餐", settings: settings, apiKey: "placeholder-not-real")
        try check(parsed.count == 1 && MockProtocol.captured?.url?.host == "open.bigmodel.cn", "stubbed photo GLM request")
        try check(MockProtocol.captured?.value(forHTTPHeaderField: "Authorization") == "Bearer placeholder-not-real", "auth header")
        MockProtocol.response = try envelope("保持规律饮食。")
        let chat = try await client.chat(messages: [.init(role: "user", content: "你好")], context: "", settings: settings, apiKey: "placeholder-not-real")
        try check(chat == "保持规律饮食。" && MockProtocol.captured?.url?.host == "api.deepseek.com", "stubbed DeepSeek request")
        MockProtocol.captured = nil
        do {
            _ = try await client.analyze(photoJPEG: Data(repeating: 0, count: 5_000_001), description: "", settings: settings, apiKey: "placeholder")
            try check(false, "expected oversized image error")
        } catch let error as AIError { try check(error == .photoTooLarge && MockProtocol.captured == nil, "5MB bound before network") }
        MockProtocol.status = 401
        MockProtocol.response = Data("secret-response".utf8)
        do {
            _ = try await client.chat(messages: [.init(role: "user", content: "hi")], context: "", settings: settings, apiKey: "placeholder")
            try check(false, "expected HTTP error")
        } catch let error as AIError { try check(error == .http(401) && !error.localizedDescription.contains("secret-response"), "safe HTTP error") }
        MockProtocol.status = 200
        MockProtocol.response = try envelope("partial", finish: "length")
        do {
            _ = try await client.chat(messages: [.init(role: "user", content: "hi")], context: "", settings: settings, apiKey: "placeholder")
            try check(false, "expected truncation")
        } catch let error as AIError { try check(error == .truncated, "truncated API response rejected") }
        MockProtocol.response = Data(#"{"choices":[{"message":{"content":"partial"}}]}"#.utf8)
        do {
            _ = try await client.chat(messages: [.init(role: "user", content: "hi")], context: "", settings: settings, apiKey: "placeholder")
            try check(false, "expected missing finish error")
        } catch let error as AIError { try check(error == .malformedResponse, "missing finish reason rejected") }
        MockProtocol.captured = nil
        do {
            _ = try await client.analyze(photoJPEG: nil, description: "苹果", settings: settings, apiKey: "")
            try check(false, "expected missing key")
        } catch let error as AIError { try check(error == .missingKey && MockProtocol.captured == nil, "missing key without network") }
        print("\nAll \(checks) core checks passed. No real provider requests were made.")
    }
}
