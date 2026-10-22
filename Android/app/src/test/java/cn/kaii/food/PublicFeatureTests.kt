package cn.kaii.food

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject

class PublicFeatureTests {
    private fun template() = FrequentFood(food = Food(name = "牛奶", grams = 200.0, unit = "mL", nutrients = Nutrients(148.0, 7.2, 10.0, 8.8)), portion = "1 盒")
    @Test fun templateRoundTrip() { val value = template(); assertEquals(value, FrequentFood.parse(value.json())) }
    @Test fun newIDsAndScaledServings() {
        val value = template(); val first = value.item(); val second = value.item(2.0)
        assertNotEquals(first.id, second.id); assertNotEquals(value.food.id, first.id)
        assertEquals(400.0, second.grams, .001); assertEquals(14.4, second.nutrients.protein, .001)
        assertEquals("mL", second.unit); assertEquals(200.0, value.food.grams, .001)
    }
    @Test fun diaryPersistsTemplates() { val value = Diary(frequentFoods = listOf(template())); assertEquals(value, Diary.parse(value.json().toString())) }
    @Test fun legacyDiaryLoadsWithoutTemplates() {
        val json = Diary(settings = AISettings(provider = "deepseek")).json(); json.remove("frequentFoods"); json.getJSONObject("settings").remove("kimiModel")
        val value = Diary.parse(json.toString())
        assertTrue(value.frequentFoods.isEmpty()); assertEquals("deepseek", value.settings.provider); assertEquals("kimi-k2.6", value.settings.kimiModel)
    }
    @Test(expected = Exception::class) fun zeroPortionsRejected() { template().item(0.0) }
    @Test(expected = Exception::class) fun invalidTemplateRejected() { FrequentFood.parse(template().json().put("portion", " ")) }
    @Test fun providersUseOfficialEndpoints() {
        assertEquals("https://api.moonshot.cn/v1/chat/completions", providerEndpoint("kimi"))
        assertEquals("kimi-k2.6", AISettings(provider = "kimi").currentModel)
        assertEquals("deepseek-flash", AISettings(provider = "deepseek").model(photo = true))
        assertTrue(AISettings.parse(JSONObject().put("provider", "kimi")).valid())
    }
    @Test fun templatesDoNotContainCredentials() { val text = Diary(frequentFoods = listOf(template())).json().toString(); assertFalse(text.contains("apiKey")); assertFalse(text.contains("PrivateProviders")) }
}
