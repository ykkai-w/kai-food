package cn.kaii.food

import org.junit.Assert.*
import org.junit.Test

class ChatTextTests {
    @Test fun spacedBoldAndBullets() {
        val value = chatText("**今日概览： **\n* **蛋白质： **132 g\n\n下一餐正常吃。")
        assertEquals("今日概览：\n• 蛋白质：132 g\n\n下一餐正常吃。", value.text)
        assertTrue(value.spanStyles.isNotEmpty())
    }
    @Test fun headingsAndChinese() {
        assertEquals("下一餐\n• 米饭\n• 鸡蛋", chatText("### 下一餐\n- 米饭\n- 鸡蛋").text)
    }
    @Test fun ordinaryTextAndUnclosedMarkup() {
        val source = "2 * 3 = 6\n还在生成 **蛋白质"
        assertEquals(source, chatText(source).text)
    }
}
