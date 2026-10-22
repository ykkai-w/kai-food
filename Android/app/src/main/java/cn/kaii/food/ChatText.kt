package cn.kaii.food

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle

fun normalizedChatMarkdown(source: String): String = Regex("\\*\\*([^*\\n]+?)\\*\\*")
    .replace(source) { match -> match.groupValues[1].trim().let { if (it.isEmpty()) match.value else "**$it**" } }
    .lines().joinToString("\n") { line ->
        if (Regex("^\\s*#{1,6}\\s+").containsMatchIn(line)) "**${line.replaceFirst(Regex("^\\s*#{1,6}\\s+"), "")}**"
        else line.replaceFirst(Regex("^(\\s*)[-*+]\\s+"), "$1• ")
    }

fun chatText(source: String): AnnotatedString = buildAnnotatedString {
    val markdown = normalizedChatMarkdown(source)
    var offset = 0
    Regex("\\*\\*([^*\\n]+?)\\*\\*|`([^`\\n]+)`").findAll(markdown).forEach { match ->
        append(markdown.substring(offset, match.range.first))
        if (match.value.startsWith("**")) withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(match.groupValues[1]) }
        else withStyle(SpanStyle(fontFamily = FontFamily.Monospace)) { append(match.groupValues[2]) }
        offset = match.range.last + 1
    }
    append(markdown.substring(offset))
}
