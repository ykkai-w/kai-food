package cn.kaii.food

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate

class CoreTests {
    @Test fun localizedExportPreservesUserText() {
        val date = LocalDate.of(2026, 9, 2)
        val meal = Meal(date = date, kind = MealKind.lunch, items = listOf(rice()), note = "妈妈做的", mealDescription = "米饭一碗")
        val words = mapOf("午餐" to "Lunch", "备注" to "Notes", "餐食描述" to "Meal description", "kaii 食记" to "kaii Food")
        val text = exportMarkdown(listOf(meal), date, date) { words[it] ?: it }
        assertTrue(text.contains("# kaii Food"))
        assertTrue(text.contains("### Lunch"))
        assertTrue(text.contains("Notes：妈妈做的"))
        assertTrue(text.contains("Meal description：米饭一碗"))
        assertEquals("米饭", meal.items.single().name)
    }
    @Test fun recollectionRoundTripAndExportWithoutPhoto() {
        val date = LocalDate.of(2026, 9, 2)
        val meal = Meal(date = date, kind = MealKind.lunch, items = listOf(rice()), mealDescription = "一碗米饭|半盘青菜")
        assertEquals(meal, Meal.parse(meal.json()))
        assertEquals("", meal.photo)
        assertTrue(exportMarkdown(listOf(meal), date, date).contains("餐食描述：一碗米饭／半盘青菜"))
    }
    @Test fun oldMealStillLoads() {
        val raw = Meal(date = LocalDate.now(), kind = MealKind.lunch, note = "旧备注").json()
        raw.remove("mealDescription")
        assertEquals("", Meal.parse(raw).mealDescription)
        assertEquals("旧备注", Meal.parse(raw).note)
    }
    @Test fun repeatedEstimateReplacesInsteadOfDuplicating() {
        val meal = Meal(date = LocalDate.of(2026, 9, 2), kind = MealKind.dinner, items = listOf(rice()), mealDescription = "米饭半碗")
        val updated = meal.withEstimate(listOf(rice().resized(75.0))).withEstimate(listOf(rice().resized(75.0)))
        assertEquals(1, updated.items.size)
        assertEquals(87.0, updated.total.kcal, .001)
        assertEquals(meal.id, updated.id); assertEquals(meal.date, updated.date)
        assertEquals(meal.kind, updated.kind); assertEquals(meal.mealDescription, updated.mealDescription)
    }
    @Test fun textInputDoesNotRequirePhoto() {
        assertTrue(MealInputMethod.description.canAnalyze(false, "鸡腿一个", ""))
        assertFalse(MealInputMethod.description.canAnalyze(true, " \n ", ""))
        assertFalse(MealInputMethod.photo.canAnalyze(false, "鸡腿一个", ""))
        assertTrue(MealInputMethod.photo.canAnalyze(true, "", ""))
        assertFalse(MealInputMethod.label.canAnalyze(true, "200mL", ""))
        assertTrue(MealInputMethod.label.canAnalyze(false, "200mL", "每100mL蛋白质3.6g"))
    }
    private fun rice() = Food(name = "米饭", grams = 150.0, nutrients = Nutrients(174.0, 3.9, 38.8, .5))
    private fun reply() = """{"items":[{"name":"牛奶","grams":200,"unit":"mL","kcal":148,"protein":7.2,"carbs":10,"fat":8.8,"source":"标签换算","uncertainty":""}]}"""
    @Test fun nutrientsScale() { assertEquals(87.0, rice().resized(75.0).nutrients.kcal, .001) }
    @Test fun nutritionSum() { assertEquals(348.0, (rice().nutrients + rice().nutrients).kcal, .001) }
    @Test fun labelMillilitersPreserved() { val food = FoodParser.parse(reply()).single(); assertEquals("mL", food.unit); assertEquals(7.2, food.nutrients.protein, .001) }
    @Test fun fencedJsonAccepted() { assertEquals(1, FoodParser.parse("```json\n${reply()}\n```").size) }
    @Test(expected = Exception::class) fun missingNutrientsRejected() { FoodParser.parse(reply().replace("\"protein\":7.2,", "")) }
    @Test(expected = Exception::class) fun negativeNutrientsRejected() { FoodParser.parse(reply().replace("7.2", "-2")) }
    @Test(expected = Exception::class) fun invalidUnitRejected() { FoodParser.parse(reply().replace("mL", "kg")) }
    @Test(expected = Exception::class) fun zeroAmountRejected() { rice().resized(0.0) }
    @Test fun emptyResultsAllowed() { assertEquals(0, FoodParser.parse("{\"items\":[]}").size) }
    @Test fun wholePortionNotPer100() { assertEquals(148.0, FoodParser.parse(reply()).single().nutrients.kcal, .001) }
    @Test fun rejectsNonfinite() { assertFalse(rice().copy(nutrients = Nutrients(Double.NaN)).valid()) }
    @Test fun rejectsImpossibleEnergy() { assertFalse(rice().copy(nutrients = Nutrients(9999.0)).valid()) }
    @Test fun dataRoundTrip() {
        val diary = Diary(listOf(Meal(date = LocalDate.of(2026, 10, 18), kind = MealKind.lunch, items = listOf(rice()))), listOf(Message("user", "中午吃什么")))
        assertEquals(diary, Diary.parse(diary.json().toString()))
    }
    @Test fun exportFiltersDates() {
        val date = LocalDate.of(2026, 10, 18)
        val text = exportMarkdown(listOf(Meal(date = date.minusDays(1), kind = MealKind.lunch, items = listOf(rice().copy(name = "昨天的饭"))), Meal(date = date, kind = MealKind.dinner, items = listOf(rice()))), date, date)
        assertTrue(text.contains("米饭")); assertFalse(text.contains("昨天的饭")); assertTrue(text.contains("174 kcal"))
    }
    @Test(expected = Exception::class) fun reversedDatesRejected() { exportMarkdown(emptyList(), LocalDate.now(), LocalDate.now().minusDays(1)) }
    @Test fun exportsEscapePipes() { val date = LocalDate.now(); val text = exportMarkdown(listOf(Meal(date = date, kind = MealKind.snack, items = listOf(rice().copy(name = "米|饭")))), date, date); assertTrue(text.contains("米／饭")) }
    @Test fun credentialsNotPersistedOrExported() { val raw = Diary().json().toString(); assertFalse(raw.contains("apiKey")); assertFalse(raw.contains("PrivateProviders")) }
    @Test(expected = Exception::class) fun futureSchemaRejected() { Diary.parse(Diary().json().put("schemaVersion", 99).toString()) }
    @Test(expected = Exception::class) fun photoTraversalRejected() {
        val meal = Meal(date = LocalDate.now(), kind = MealKind.lunch).json().put("photo", "../../credentials")
        Meal.parse(meal)
    }
    @Test fun limitedStreamDoesNotOverread() { assertEquals("abc", "abcdef".byteInputStream().use { String(it.readLimitedBytes(3)) }) }
    @Test fun settingsValidation() { assertFalse(AISettings(glmModel = "bad model").valid()); assertFalse(AISettings(proteinGoal = 301.0).valid()); assertTrue(AISettings().valid()) }
}
