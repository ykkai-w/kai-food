import Foundation

public enum MealInputMethod: String, CaseIterable, Sendable {
    case description, photo, label
    public var title: String {
        switch self {
        case .description: return "描述记录"
        case .photo: return "拍照记录"
        case .label: return "包装标签"
        }
    }
    public func canAnalyze(hasPhoto: Bool, description: String, labelText: String) -> Bool {
        let hasDescription = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch self {
        case .description: return hasDescription
        case .photo: return hasPhoto
        case .label: return hasDescription && !labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

public enum MealKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case breakfast, lunch, dinner, snack
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .snack: return "加餐"
        }
    }
}

/// All values describe the entire recorded portion, never an implicit 100 g.
public struct Nutrients: Codable, Equatable, Sendable {
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public init(kcal: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.kcal = kcal; self.protein = protein; self.carbs = carbs; self.fat = fat
    }
    public static func + (lhs: Self, rhs: Self) -> Self {
        .init(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein,
              carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat)
    }
    public func scaled(by multiplier: Double) -> Self {
        .init(kcal: kcal * multiplier, protein: protein * multiplier,
              carbs: carbs * multiplier, fat: fat * multiplier)
    }
    public var isValid: Bool {
        [kcal, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 }
    }
    public static func per100(kcal: Double, protein: Double, carbs: Double, fat: Double, grams: Double) -> Self {
        Self(kcal: kcal, protein: protein, carbs: carbs, fat: fat).scaled(by: grams / 100)
    }
    public static func kcal(fromKilojoules kilojoules: Double) -> Double { kilojoules / 4.184 }
}

public struct FoodItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var grams: Double
    /// Quantity unit. The historical `grams` field stores the amount in this unit.
    public var unit: String
    public var nutrients: Nutrients
    public var source: String
    public var uncertainty: String
    public init(id: UUID = UUID(), name: String, grams: Double, unit: String = "g", nutrients: Nutrients,
                source: String = "手动", uncertainty: String = "份量与烹调油待确认") {
        self.id = id; self.name = name; self.grams = grams; self.nutrients = nutrients
        self.unit = unit; self.source = source; self.uncertainty = uncertainty
    }
    private enum CodingKeys: String, CodingKey { case id, name, grams, unit, nutrients, source, uncertainty }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        grams = try values.decode(Double.self, forKey: .grams)
        unit = try values.decodeIfPresent(String.self, forKey: .unit) ?? "g"
        nutrients = try values.decode(Nutrients.self, forKey: .nutrients)
        source = try values.decode(String.self, forKey: .source)
        uncertainty = try values.decode(String.self, forKey: .uncertainty)
    }
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        ["g", "mL"].contains(unit) && grams.isFinite && grams > 0 && grams <= 10_000 && nutrients.isValid &&
        nutrients.kcal <= 10_000 && nutrients.kcal <= grams * 10 &&
        [nutrients.protein, nutrients.carbs, nutrients.fat].allSatisfy { $0 <= grams * 1.2 }
    }
    public func resized(toGrams grams: Double) -> Self? {
        guard self.grams > 0, grams.isFinite, grams > 0 else { return nil }
        var copy = self
        copy.nutrients = nutrients.scaled(by: grams / self.grams)
        copy.grams = grams
        return copy.isValid ? copy : nil
    }
}

public struct MealEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var kind: MealKind
    public var items: [FoodItem]
    public var note: String
    public var photoFilename: String?
    /// The user's original meal recollection; optional for older saved records.
    public var mealDescription: String?
    public init(id: UUID = UUID(), date: Date = Date(), kind: MealKind, items: [FoodItem],
                note: String = "", photoFilename: String? = nil, mealDescription: String? = nil) {
        self.id = id; self.date = date; self.kind = kind; self.items = items
        self.note = note; self.photoFilename = photoFilename
        self.mealDescription = mealDescription
    }
    public var total: Nutrients { items.reduce(Nutrients()) { $0 + $1.nutrients } }
}

public enum AIProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case glm, deepseek, kimi
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .glm: return "GLM"; case .deepseek: return "DeepSeek"; case .kimi: return "Kimi" }
    }
    public var keyURL: URL {
        switch self {
        case .glm: return URL(string: "https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys")!
        case .deepseek: return URL(string: "https://platform.deepseek.com/api_keys")!
        case .kimi: return URL(string: "https://platform.moonshot.cn/console/api-keys")!
        }
    }
    public var endpoint: URL {
        switch self {
        case .glm: return URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!
        case .deepseek: return URL(string: "https://api.deepseek.com/chat/completions")!
        case .kimi: return URL(string: "https://api.moonshot.cn/v1/chat/completions")!
        }
    }
}

/// API credentials deliberately do not belong to this persistable type.
public struct AISettings: Codable, Equatable, Sendable {
    public var visionModel: String
    public var glmChatModel: String
    public var deepseekModel: String
    public var kimiModel: String
    public var chatProvider: AIProvider
    public init(visionModel: String = "glm-4.6v-flashx", glmChatModel: String = "glm-4.7-flashx",
                deepseekModel: String = "deepseek-flash", chatProvider: AIProvider = .glm,
                kimiModel: String = "kimi-k2.6") {
        self.visionModel = visionModel; self.glmChatModel = glmChatModel
        self.deepseekModel = deepseekModel; self.chatProvider = chatProvider
        self.kimiModel = kimiModel
    }
    private enum CodingKeys: String, CodingKey { case visionModel, glmChatModel, deepseekModel, chatProvider, kimiModel }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(visionModel: try c.decodeIfPresent(String.self, forKey: .visionModel) ?? "glm-4.6v-flashx",
                  glmChatModel: try c.decodeIfPresent(String.self, forKey: .glmChatModel) ?? "glm-4.7-flashx",
                  deepseekModel: try c.decodeIfPresent(String.self, forKey: .deepseekModel) ?? "deepseek-flash",
                  chatProvider: try c.decodeIfPresent(AIProvider.self, forKey: .chatProvider) ?? .glm,
                  kimiModel: try c.decodeIfPresent(String.self, forKey: .kimiModel) ?? "kimi-k2.6")
    }
    public func model(for provider: AIProvider, photo: Bool = false) -> String {
        switch provider {
        case .glm: return photo ? visionModel : glmChatModel
        case .deepseek: return deepseekModel
        case .kimi: return kimiModel
        }
    }
    public var isValid: Bool {
        [visionModel, glmChatModel, deepseekModel, kimiModel].allSatisfy {
            !$0.isEmpty && $0.count <= 100 && !$0.contains(where: { $0.isWhitespace })
        }
    }
}

public struct FrequentFood: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var food: FoodItem
    public var portion: String
    public init(id: UUID = UUID(), food: FoodItem, portion: String = "1 份") {
        self.id = id; self.food = food; self.portion = portion
    }
    public var isValid: Bool {
        food.isValid && !portion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && portion.count <= 80
    }
    public func item(servings: Double = 1) -> FoodItem? {
        guard isValid, servings.isFinite, servings > 0,
              var result = food.resized(toGrams: food.grams * servings) else { return nil }
        result.id = UUID()
        return result
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var role: String
    public var content: String
    public init(id: UUID = UUID(), role: String, content: String) {
        self.id = id; self.role = role; self.content = content
    }
}
