import Foundation

public enum AIError: LocalizedError, Equatable {
    case missingKey, missingInput, invalidModel, photoTooLarge, malformedResponse, invalidNutrition
    case http(Int), truncated, emptyResponse, insufficientDetails
    public var errorDescription: String? {
        switch self {
        case .missingKey: return "请先在设置中保存对应平台的 API Key。"
        case .missingInput: return "请添加一张照片或填写食物描述。"
        case .invalidModel: return "模型名称不能为空，且不能包含空格或换行。"
        case .photoTooLarge: return "照片为空或超过 5 MB，请选择压缩后的 JPEG 图片。"
        case .malformedResponse: return "AI 返回的格式不完整，尚未保存。请重试或手动填写。"
        case .invalidNutrition: return "AI 估算中有缺失或不合理的营养数值，尚未保存。请重试或手动填写。"
        case .truncated: return "AI 回复被截断或未正常完成，请重试。"
        case .emptyResponse: return "模型未返回内容，请检查模型名称、额度后重试。"
        case .insufficientDetails: return "再写一下具体食物和大概份量，然后重新估算。"
        case .http(let code):
            switch code {
            case 401, 403: return "API 授权失败（\(code)），请检查 Key 和模型权限。"
            case 429: return "服务暂时繁忙或请求受限（429），请稍后重试。"
            default: return "模型服务返回 HTTP \(code)。请检查模型名称、账户额度或稍后重试。"
            }
        }
    }
}

public enum NutritionParser {
    private struct Response: Decodable { var items: [Item] }
    private struct Item: Decodable {
        var name: String
        var grams: Double
        var unit: String?
        var kcal: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var source: String
        var uncertainty: String
    }

    /// A missing numeric value is an error, never zero. Only the explicit schema is accepted.
    public static func parse(_ input: String) throws -> [FoodItem] {
        var json = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```json\n"), json.hasSuffix("```") {
            json = String(json.dropFirst(8).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if json.hasPrefix("```\n"), json.hasSuffix("```") {
            json = String(json.dropFirst(4).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard json.utf8.count <= 256_000, let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw AIError.malformedResponse
        }
        guard !decoded.items.isEmpty else { throw AIError.insufficientDetails }
        guard decoded.items.count <= 30 else { throw AIError.invalidNutrition }
        return try decoded.items.map { raw in
            let name = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let uncertainty = raw.uncertainty.trimmingCharacters(in: .whitespacesAndNewlines)
            let food = FoodItem(name: name, grams: raw.grams, unit: raw.unit ?? "g",
                                nutrients: .init(kcal: raw.kcal, protein: raw.protein, carbs: raw.carbs, fat: raw.fat),
                                source: raw.source == "标签换算" ? "AI标签换算（待核对）" : raw.source,
                                uncertainty: uncertainty)
            guard food.isValid, name.count <= 200, !uncertainty.isEmpty, uncertainty.count <= 2000,
                  ["AI估算", "标签换算"].contains(raw.source) else { throw AIError.invalidNutrition }
            return food
        }
    }
}
