import Foundation

public enum MealExport {
    public static let maximumDays = 366
    private static let excessiveRangeMessage = "单次最多导出 366 个自然日，请缩短日期范围后重试。"
    public static func markdown(entries: [MealEntry], from: Date, to: Date, localize: (String) -> String = { $0 }) -> String {
        markdown(entries: entries, from: from, to: to, calendar: .current, localize: localize)
    }

    public static func markdown(entries: [MealEntry], from: Date, to: Date, calendar: Calendar, localize: (String) -> String = { $0 }) -> String {
        let start = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: to)
        guard start <= last, let end = calendar.date(byAdding: .day, value: 1, to: last) else {
            return localize("日期范围无效。")
        }
        guard let elapsedDays = calendar.dateComponents([.day], from: start, to: last).day,
              (0..<maximumDays).contains(elapsedDays) else { return localize(excessiveRangeMessage) }
        let records = entries.filter { $0.date >= start && $0.date < end }.sorted { $0.date < $1.date }
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_CN"); formatter.dateFormat = "yyyy-MM-dd"
        let time = DateFormatter()
        time.timeZone = calendar.timeZone; time.locale = Locale(identifier: "zh_CN"); time.dateFormat = "HH:mm"
        var lines = ["# \(localize("kaii 食记"))", "", "\(formatter.string(from: start)) \(localize("至")) \(formatter.string(from: last)) · \(calendar.timeZone.identifier)", ""]
        var day = start
        while day <= last {
            let daily = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            lines += ["## \(formatter.string(from: day))", ""]
            for kind in MealKind.allCases {
                let meals = daily.filter { $0.kind == kind }
                if meals.isEmpty {
                    lines += ["### \(localize(kind.displayName)) · \(localize("未记录"))", ""]
                    continue
                }
                for meal in meals {
                    lines += ["### \(localize(kind.displayName)) · \(time.string(from: meal.date))", "",
                              localize("| 食物 | 份量 | 千卡 | 蛋白质 g | 碳水 g | 脂肪 g | 来源 | 估算说明 |"),
                              "| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |"]
                    for food in meal.items {
                        lines.append("| \(escape(food.name)) | \(number(food.grams)) \(escape(food.unit)) | \(number(food.nutrients.kcal)) | \(number(food.nutrients.protein)) | \(number(food.nutrients.carbs)) | \(number(food.nutrients.fat)) | \(escape(localize(food.source))) | \(escape(food.uncertainty)) |")
                    }
                    lines += ["", "\(localize("小计")) \(summary(meal.total, localize: localize))"]
                    if let description = meal.mealDescription, !description.isEmpty { lines.append("\(localize("餐食描述")) \(escape(description))") }
                    if !meal.note.isEmpty { lines.append("\(localize("备注")) \(escape(meal.note))") }
                    if meal.photoFilename != nil { lines.append(localize("照片保存在 App 内。")) }
                    lines.append("")
                }
            }
            if !daily.isEmpty {
                let total = daily.reduce(Nutrients()) { $0 + $1.total }
                lines += ["**\(localize("已记录合计")) \(summary(total, localize: localize))**", ""]
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return lines.joined(separator: "\n")
    }

    public static func csv(entries: [MealEntry], from: Date, to: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)), start < end else { return "日期范围无效。" }
        guard let elapsedDays = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: to)).day,
              (0..<maximumDays).contains(elapsedDays) else { return excessiveRangeMessage }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        var rows = [["记录时间", "餐次", "食物", "份量数值", "份量单位", "整份千卡", "蛋白质克", "碳水克", "脂肪克", "来源", "估算说明", "备注", "餐食描述"]]
        for meal in entries.filter({ $0.date >= start && $0.date < end }).sorted(by: { $0.date < $1.date }) {
            for food in meal.items {
                rows.append([formatter.string(from: meal.date), meal.kind.displayName, food.name, number(food.grams), food.unit,
                             number(food.nutrients.kcal), number(food.nutrients.protein), number(food.nutrients.carbs), number(food.nutrients.fat),
                             food.source, food.uncertainty, meal.note, meal.mealDescription ?? ""])
            }
        }
        return "\u{FEFF}" + rows.map { $0.map(csvCell).joined(separator: ",") }.joined(separator: "\r\n")
    }

    private static func number(_ value: Double) -> String {
        guard value.isFinite else { return "未知" }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    private static func summary(_ n: Nutrients, localize: (String) -> String = { $0 }) -> String {
        "\(number(n.kcal)) \(localize("千卡"))；\(localize("蛋白质")) \(number(n.protein)) g；\(localize("碳水")) \(number(n.carbs)) g；\(localize("脂肪")) \(number(n.fat)) g"
    }
    private static func escape(_ string: String) -> String {
        string.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
    private static func csvCell(_ string: String) -> String {
        // Prevent spreadsheet formula injection in exported user/model supplied fields.
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = ["=", "+", "-", "@"].contains(String(trimmed.prefix(1))) ? "'" + string : string
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
