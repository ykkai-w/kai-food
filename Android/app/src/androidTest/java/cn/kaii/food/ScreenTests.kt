package cn.kaii.food

import android.content.ClipboardManager
import android.content.Context
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ScreenTests {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    @Before fun enterApp() {
        compose.waitUntil(15_000) {
            compose.onAllNodesWithText("先逛逛，稍后设置").fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodesWithText("记下一餐").fetchSemanticsNodes().isNotEmpty()
        }
        if (compose.onAllNodesWithText("先逛逛，稍后设置").fetchSemanticsNodes().isNotEmpty()) {
            compose.onNodeWithText("先逛逛，稍后设置").performScrollTo().performClick()
        }
        compose.waitUntil(15_000) { compose.onAllNodesWithText("记下一餐").fetchSemanticsNodes().isNotEmpty() }
    }
    @Test fun recalledMealDoesNotRequirePhotoAndKeepsTextAcrossModes() {
        compose.waitUntil(15_000) { compose.onAllNodesWithText("记下一餐").fetchSemanticsNodes().isNotEmpty() }
        compose.onAllNodesWithText("加餐").onLast().performScrollTo().performClick()
        compose.onNodeWithText("AI 估算这一餐").assertIsNotEnabled()
        compose.onNodeWithText("餐食描述").performTextInput("测试餐：香蕉一根")
        compose.onNodeWithText("AI 估算这一餐").assertIsEnabled()
        compose.onNodeWithText("拍照记录").performClick()
        compose.onNodeWithText("识别这一餐").assertIsNotEnabled()
        compose.onNodeWithText("描述记录").performClick()
        compose.onNodeWithText("测试餐：香蕉一根").assertExists()
        compose.onNodeWithText("AI 估算这一餐").assertIsEnabled()
        compose.onNodeWithContentDescription("关闭").performClick()
        compose.onNodeWithText("退出", useUnmergedTree = true).performClick()
    }
    @Test fun manualMealSaveAndExport() {
        compose.waitUntil(15_000) { compose.onAllNodesWithText("记下一餐").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("午餐").performScrollTo().performClick()
        compose.onNodeWithText("手动添加").performScrollTo().performClick()
        compose.onNodeWithText("食物名称").performTextInput("Test Rice")
        compose.onNodeWithText("食用份量").performTextReplacement("150")
        compose.onNodeWithText("能量 · kcal").performScrollTo().performTextInput("174")
        compose.onNodeWithText("蛋白质 · g").performScrollTo().performTextInput("3.9")
        compose.onNodeWithText("碳水 · g").performScrollTo().performTextInput("38.8")
        compose.onNodeWithText("脂肪 · g").performScrollTo().performTextInput("0.5")
        compose.onNodeWithText("保存", useUnmergedTree = true).performClick()
        compose.onNodeWithText("保存这餐").performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithText("保存这餐").fetchSemanticsNodes().isEmpty() }
        compose.onNodeWithText("导出").performClick()
        compose.onNodeWithText("复制食记").performScrollTo().performClick()
        compose.onNodeWithText("好").performClick()
        val clipboard = compose.activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        compose.runOnUiThread { assertTrue(clipboard.primaryClip?.getItemAt(0)?.text.toString().contains("Test Rice")) }
    }
    @Test fun navigationAndModelsVisible() {
        compose.onNodeWithText("问 AI").performClick()
        compose.onNodeWithContentDescription("切换模型").performClick()
        compose.onNodeWithText("DeepSeek").assertExists()
        compose.onNodeWithText("Kimi").assertExists()
        compose.onNodeWithText("glm-4.7-flashx").assertExists()
        compose.onNodeWithText("DeepSeek").performClick()
        compose.onNodeWithText("好").performClick()
        compose.onNodeWithText("设置").performClick()
        compose.onNodeWithText("v1.0").assertExists()
    }
}
