package cn.kaii.food

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONObject
import java.util.Locale

object L10n {
    val choices = linkedMapOf("system" to "跟随系统", "zh-Hans" to "简体中文", "en" to "English", "zh-Hant" to "繁體中文")
    private var preferences: SharedPreferences? = null
    private var english = emptyMap<String, String>()
    private var traditional = emptyMap<String, String>()
    var choice by mutableStateOf("system")
        private set
    fun initialize(context: Context) {
        preferences = context.getSharedPreferences("kaii-language", Context.MODE_PRIVATE)
        choice = preferences?.getString("language", "system")?.takeIf { it in choices } ?: "system"
        fun catalog(name: String): Map<String, String> {
            val data = JSONObject(context.assets.open("$name.json").bufferedReader().use { it.readText() })
            return data.keys().asSequence().associateWith { data.getString(it) }
        }
        english = catalog("English")
        traditional = catalog("Traditional")
    }
    fun select(value: String) {
        if (value !in choices) return
        preferences?.edit()?.putString("language", value)?.apply()
        choice = value
    }
    fun resolve(value: String, system: String): String {
        if (value in choices && value != "system") return value
        val tag = system.lowercase(Locale.ROOT)
        if (!tag.startsWith("zh")) return "en"
        return if (listOf("hant", "tw", "hk", "mo").any { tag.contains(it) }) "zh-Hant" else "zh-Hans"
    }
    val language get() = resolve(choice, Locale.getDefault().toLanguageTag())
    val locale: Locale get() = Locale.forLanguageTag(language)
    val responseLanguage get() = when (language) { "en" -> "English"; "zh-Hant" -> "繁體中文"; else -> "简体中文" }
    fun text(key: String, vararg arguments: Any?): String {
        val value = when (language) { "en" -> english[key] ?: key; "zh-Hant" -> traditional[key] ?: key; else -> key }
        return Regex("\\{(\\d+)\\}").replace(value) { match ->
            val index = match.groupValues[1].toIntOrNull()
            if (index != null && index in arguments.indices) arguments[index].toString() else match.value
        }
    }
}
