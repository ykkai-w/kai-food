package cn.kaii.food

import org.junit.Assert.assertEquals
import org.junit.Test

class LanguageTests {
    @Test fun systemLanguageResolution() {
        assertEquals("en", L10n.resolve("system", "en-US"))
        assertEquals("zh-Hans", L10n.resolve("system", "zh-CN"))
        assertEquals("zh-Hant", L10n.resolve("system", "zh-Hant-HK"))
        assertEquals("zh-Hant", L10n.resolve("system", "zh-TW"))
        assertEquals("en", L10n.resolve("system", "fr-FR"))
    }
    @Test fun explicitChoiceWins() {
        assertEquals("en", L10n.resolve("en", "zh-CN"))
        assertEquals("zh-Hans", L10n.resolve("zh-Hans", "en-US"))
        assertEquals("zh-Hant", L10n.resolve("zh-Hant", "en-US"))
    }
}
