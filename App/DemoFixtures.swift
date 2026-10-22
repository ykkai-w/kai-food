#if PUBLIC_UI_TEST
import Foundation
import KaiiFoodCore

/// Synthetic fixtures for the isolated screenshot build only.
@MainActor enum DemoFixtures {
    static func prepare() throws {
        if try LocalFiles.load([MealEntry].self, filename: "meals.json") == nil {
            func food(_ name: String, _ grams: Double, _ kcal: Double, _ protein: Double, _ carbs: Double, _ fat: Double, unit: String = "g") -> FoodItem {
                .init(name: name, grams: grams, unit: unit, nutrients: .init(kcal: kcal, protein: protein, carbs: carbs, fat: fat), source: "手动", uncertainty: "演示数值")
            }
            func time(_ hour: Int) -> Date { Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())! }
            let milk = food("纯牛奶", 250, 160, 8, 12, 9, unit: "mL")
            let eggs = food("水煮鸡蛋", 100, 144, 13, 1, 10)
            let bread = food("全麦面包", 70, 175, 7, 30, 3)
            let powder = food("乳清蛋白粉", 30, 120, 24, 3, 1.3)
            let banana = food("香蕉", 120, 107, 1.3, 27, 0.4)
            var photo: String?
            #if SWIFT_PACKAGE
            let resources = Bundle.module
            #else
            let resources = Bundle.main
            #endif
            if let url = resources.url(forResource: "MealLunch", withExtension: "png") {
                photo = try LocalFiles.savePhoto(Data(contentsOf: url))
            }
            let meals = [
                MealEntry(date: time(8), kind: .breakfast, items: [milk, eggs, bread], note: "示例餐食", mealDescription: "一杯牛奶，两个水煮蛋，两片全麦面包。"),
                MealEntry(date: time(12), kind: .lunch, items: [food("杂粮饭", 200, 232, 5, 49, 1.5), food("鸡腿肉", 150, 255, 31, 2, 14), food("清炒时蔬", 200, 100, 4, 10, 5)], note: "示例餐食，图片为插图", photoFilename: photo, mealDescription: "杂粮饭一碗、鸡腿肉一份、青菜一份。"),
                MealEntry(date: time(18), kind: .dinner, items: [food("煎三文鱼", 150, 312, 30, 0, 21), food("米饭", 180, 209, 4.7, 46, 0.6), food("西兰花", 150, 70, 4, 8, 2.5)], note: "示例餐食", mealDescription: "三文鱼、米饭，还有一盘西兰花。"),
                MealEntry(date: time(15), kind: .snack, items: [powder, banana], note: "示例餐食", mealDescription: "一勺蛋白粉、一根香蕉。")
            ]
            try LocalFiles.save(meals, filename: "meals.json")
            try LocalFiles.save([FrequentFood(food: powder, portion: "1 勺"), FrequentFood(food: eggs, portion: "2 个"), FrequentFood(food: milk, portion: "1 盒"), FrequentFood(food: bread, portion: "2 片")], filename: "frequent-foods.json")
            UserDefaults.standard.set(120.0, forKey: ProteinGoalPreference.key)
        }
        if ProcessInfo.processInfo.arguments.contains("--demo-chat") {
            try LocalFiles.save([
                ChatMessage(role: "user", content: "【示例问答】下午训练，晚餐在食堂怎么搭配？"),
                ChatMessage(role: "assistant", content: "可以选一份米饭、一份鱼肉或鸡肉，再配两种蔬菜。\n\n今天已经喝了牛奶、吃了鸡蛋，晚餐正常吃就好。训练后如果还饿，可以加根香蕉或一杯酸奶。\n\n食堂菜偏油的话，夹菜时少带汤汁，也可以搭一份清蒸或水煮菜。")
            ], filename: "chat.json")
        }
    }
}
#endif
