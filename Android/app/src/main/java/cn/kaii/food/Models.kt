package cn.kaii.food

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.util.Locale
import java.util.UUID

data class Nutrients(val kcal: Double = 0.0, val protein: Double = 0.0, val carbs: Double = 0.0, val fat: Double = 0.0) {
    operator fun plus(other: Nutrients) = Nutrients(kcal + other.kcal, protein + other.protein, carbs + other.carbs, fat + other.fat)
    fun scaled(factor: Double) = Nutrients(kcal * factor, protein * factor, carbs * factor, fat * factor)
    fun valid() = listOf(kcal, protein, carbs, fat).all { it.isFinite() && it >= 0 }
    fun json() = JSONObject().put("kcal", kcal).put("protein", protein).put("carbs", carbs).put("fat", fat)
    companion object {
        fun parse(o: JSONObject) = Nutrients(o.getDouble("kcal"), o.getDouble("protein"), o.getDouble("carbs"), o.getDouble("fat"))
    }
}
data class Food(val id: String = UUID.randomUUID().toString(), val name: String, val grams: Double,
                val unit: String = "g", val nutrients: Nutrients, val source: String = "手动", val uncertainty: String = "") {
    fun valid() = name.isNotBlank() && name.length <= 200 && grams.isFinite() && grams > 0 && grams <= 10_000 &&
        unit in listOf("g", "mL") && nutrients.valid() && nutrients.kcal <= 10_000 && nutrients.kcal <= grams * 10 &&
        listOf(nutrients.protein, nutrients.carbs, nutrients.fat).all { it <= grams * 1.2 }
    fun resized(amount: Double): Food = copy(grams = amount, nutrients = nutrients.scaled(amount / grams)).also { require(it.valid()) }
    fun json() = JSONObject().put("id", id).put("name", name).put("grams", grams).put("unit", unit)
        .put("nutrients", nutrients.json()).put("source", source).put("uncertainty", uncertainty)
    companion object {
        fun parse(o: JSONObject) = Food(o.getString("id"), o.getString("name"), o.getDouble("grams"),
            o.optString("unit", "g"), Nutrients.parse(o.getJSONObject("nutrients")), o.optString("source", "手动"), o.optString("uncertainty"))
            .also { require(it.valid()) { "食物数据不完整" } }
    }
}
enum class MealKind(val titleKey: String, val asset: String) {
    breakfast("早餐", "MealBreakfast"), lunch("午餐", "MealLunch"), dinner("晚餐", "MealDinner"), snack("加餐", "MealSnack");
    val title: String get() = L10n.text(titleKey)
}
enum class MealInputMethod(val titleKey: String) {
    description("描述记录"), photo("拍照记录"), label("包装标签");
    val title: String get() = L10n.text(titleKey)
    fun canAnalyze(hasPhoto: Boolean, description: String, labelText: String): Boolean = when (this) {
        MealInputMethod.description -> description.isNotBlank()
        photo -> hasPhoto
        label -> description.isNotBlank() && labelText.isNotBlank()
    }
}
data class Meal(val id: String = UUID.randomUUID().toString(), val date: LocalDate, val kind: MealKind,
                val items: List<Food> = emptyList(), val note: String = "", val photo: String = "", val mealDescription: String = "") {
    val total: Nutrients get() = items.fold(Nutrients()) { sum, food -> sum + food.nutrients }
    fun json() = JSONObject().put("id", id).put("date", date.toString()).put("kind", kind.name)
        .put("items", JSONArray(items.map { it.json() })).put("note", note).put("photo", photo).put("mealDescription", mealDescription)
    fun withEstimate(estimate: List<Food>): Meal {
        require(estimate.isNotEmpty() && estimate.all { it.valid() })
        return copy(items = estimate)
    }
    companion object {
        fun parse(o: JSONObject): Meal {
            val array = o.getJSONArray("items")
            require(array.length() <= 100)
            val photo = o.optString("photo")
            require(photo.isEmpty() || photo.matches(Regex("[a-fA-F0-9-]+\\.jpg")))
            return Meal(o.getString("id"), LocalDate.parse(o.getString("date")), MealKind.valueOf(o.getString("kind")),
                (0 until array.length()).map { Food.parse(array.getJSONObject(it)) }, o.optString("note"), photo, o.optString("mealDescription"))
        }
    }
}
data class Message(val role: String, val content: String) {
    fun json() = JSONObject().put("role", role).put("content", content)
}
data class AISettings(val provider: String = "glm", val glmModel: String = "glm-4.7-flashx",
                      val visionModel: String = "glm-4.6v-flashx", val deepseekModel: String = "deepseek-flash",
                      val proteinGoal: Double = 0.0, val kimiModel: String = "kimi-k2.6") {
    fun model(id: String = provider, photo: Boolean = false) = when (id) { "glm" -> if (photo) visionModel else glmModel; "deepseek" -> deepseekModel; "kimi" -> kimiModel; else -> error("请选择 AI 服务") }
    val currentModel get() = model()
    fun json() = JSONObject().put("provider", provider).put("glmModel", glmModel).put("visionModel", visionModel)
        .put("deepseekModel", deepseekModel).put("proteinGoal", proteinGoal).put("kimiModel", kimiModel)
    fun valid() = provider in providers.keys && listOf(glmModel, visionModel, deepseekModel, kimiModel).all {
        it.isNotBlank() && it.length <= 100 && !it.any(Char::isWhitespace)
    } && proteinGoal.isFinite() && proteinGoal in 0.0..300.0
    companion object {
        fun parse(o: JSONObject) = AISettings(o.optString("provider", "glm"), o.optString("glmModel", "glm-4.7-flashx"),
            o.optString("visionModel", "glm-4.6v-flashx"), o.optString("deepseekModel", "deepseek-flash"), o.optDouble("proteinGoal", 0.0), o.optString("kimiModel", "kimi-k2.6"))
            .also { require(it.valid()) }
    }
}
val providers = linkedMapOf("glm" to "GLM", "deepseek" to "DeepSeek", "kimi" to "Kimi")
fun providerEndpoint(id: String): String = when (id) {
    "glm" -> "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    "deepseek" -> "https://api.deepseek.com/chat/completions"
    "kimi" -> "https://api.moonshot.cn/v1/chat/completions"
    else -> error("请选择 AI 服务")
}
fun providerKeyURL(id: String): String = when (id) {
    "glm" -> "https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys"
    "deepseek" -> "https://platform.deepseek.com/api_keys"
    "kimi" -> "https://platform.moonshot.cn/console/api-keys"
    else -> error("请选择 AI 服务")
}
data class FrequentFood(val id: String = UUID.randomUUID().toString(), val food: Food, val portion: String = "1 份") {
    fun valid() = food.valid() && portion.isNotBlank() && portion.length <= 80
    fun item(servings: Double = 1.0): Food {
        require(valid() && servings.isFinite() && servings > 0)
        return food.resized(food.grams * servings).copy(id = UUID.randomUUID().toString())
    }
    fun json() = JSONObject().put("id", id).put("food", food.json()).put("portion", portion)
    companion object {
        fun parse(o: JSONObject) = FrequentFood(o.getString("id"), Food.parse(o.getJSONObject("food")), o.getString("portion")).also { require(it.valid()) }
    }
}
data class Diary(val meals: List<Meal> = emptyList(), val messages: List<Message> = emptyList(), val settings: AISettings = AISettings(), val frequentFoods: List<FrequentFood> = emptyList()) {
    fun json() = JSONObject().put("schemaVersion", 1).put("meals", JSONArray(meals.map { it.json() }))
        .put("messages", JSONArray(messages.map { it.json() })).put("settings", settings.json())
        .put("frequentFoods", JSONArray(frequentFoods.map { it.json() }))
    companion object {
        fun parse(text: String): Diary {
            require(text.length < 20_000_000)
            val o = JSONObject(text)
            require(o.getInt("schemaVersion") == 1) { "请更新 App 后再读取这份备份" }
            val meals = o.getJSONArray("meals")
            val messages = o.optJSONArray("messages") ?: JSONArray()
            val favorites = o.optJSONArray("frequentFoods") ?: JSONArray()
            return Diary((0 until meals.length()).map { Meal.parse(meals.getJSONObject(it)) },
                (0 until messages.length()).map { messages.getJSONObject(it).let { m ->
                    Message(m.getString("role"), m.getString("content")).also { require(it.role in listOf("user", "assistant")) }
                } }, AISettings.parse(o.optJSONObject("settings") ?: JSONObject()), (0 until favorites.length()).map { FrequentFood.parse(favorites.getJSONObject(it)) })
        }
    }
}
object FoodParser {
    fun parse(text: String): List<Food> {
        val first = text.indexOf('{'); val last = text.lastIndexOf('}')
        require(first >= 0 && last > first) { "识别结果不完整，请重试" }
        val items = JSONObject(text.substring(first, last + 1)).getJSONArray("items")
        require(items.length() <= 30)
        return (0 until items.length()).map { index ->
            val o = items.getJSONObject(index)
            Food(name = o.getString("name"), grams = o.getDouble("grams"), unit = o.optString("unit", "g"),
                nutrients = Nutrients.parse(o), source = if (o.optString("source") == "标签换算") "标签换算" else "AI估算",
                uncertainty = o.optString("uncertainty")).also { require(it.valid()) { "识别结果有异常数值，请重试或手动填写" } }
        }
    }
}
fun Double.pretty(): String = if (this % 1.0 == 0.0) toLong().toString() else String.format(Locale.ROOT, "%.1f", this)
fun exportMarkdown(meals: List<Meal>, start: LocalDate, end: LocalDate, localize: (String) -> String = { it }): String {
    require(!end.isBefore(start))
    fun clean(s: String) = s.replace("|", "／").replace("\r", " ").replace("\n", " ")
    val selected = meals.filter { !it.date.isBefore(start) && !it.date.isAfter(end) }.sortedWith(compareBy({ it.date }, { it.kind.ordinal }))
    return buildString {
        append("# ${localize("kaii 食记")}\n\n$start — $end\n\n")
        if (selected.isEmpty()) append("${localize("未记录")}\n")
        selected.groupBy { it.date }.forEach { (date, entries) ->
            append("## $date\n\n")
            entries.forEach { meal ->
                append("### ${localize(meal.kind.titleKey)}\n\n${localize("| 食物 | 份量 | 千卡 | 蛋白质 g | 碳水 g | 脂肪 g | 来源 |")}\n|---|---:|---:|---:|---:|---:|---|\n")
                meal.items.forEach { f -> append("| ${clean(f.name)} | ${f.grams.pretty()} ${f.unit} | ${f.nutrients.kcal.pretty()} | ${f.nutrients.protein.pretty()} | ${f.nutrients.carbs.pretty()} | ${f.nutrients.fat.pretty()} | ${clean(localize(f.source))} |\n") }
                if (meal.note.isNotBlank()) append("\n${localize("备注")}：${clean(meal.note)}\n")
                if (meal.mealDescription.isNotBlank()) append("\n${localize("餐食描述")}：${clean(meal.mealDescription)}\n")
                append("\n")
            }
            val total = entries.fold(Nutrients()) { sum, meal -> sum + meal.total }
            append("${localize("已记录合计")}：${total.kcal.pretty()} kcal；${localize("蛋白质")} ${total.protein.pretty()} g；${localize("碳水")} ${total.carbs.pretty()} g；${localize("脂肪")} ${total.fat.pretty()} g。\n\n")
        }
    }
}
