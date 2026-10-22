package cn.kaii.food

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.LocalDate

@RunWith(AndroidJUnit4::class)
class DeviceTests {
    private val context: Context get() = InstrumentationRegistry.getInstrumentation().targetContext
    @Test fun atomicStorageRoundTrip() {
        val files = LocalFiles(context)
        val before = files.read()
        try {
            val sample = Diary(listOf(Meal(date = LocalDate.now(), kind = MealKind.lunch, items = listOf(Food(name = "测试米饭", grams = 150.0, nutrients = Nutrients(174.0, 3.9, 38.8, .5))))))
            files.write(sample); assertEquals(sample, files.read())
        } finally { files.write(before) }
    }
    @Test fun keyVaultEncryptsAndRestores() {
        val vault = KeyVault(context); val original = vault.read("glm")
        val synthetic = "test-only-synthetic-not-a-real-key-123456"
        try {
            vault.save("glm", synthetic); assertEquals(synthetic, vault.read("glm"))
            val raw = context.getSharedPreferences("credentials", Context.MODE_PRIVATE).getString("glm", "")!!
            assertFalse(raw.contains(synthetic)); assertTrue(raw.contains(':'))
            vault.remove("glm"); vault.importBundled(); assertEquals("", vault.read("glm"))
        } finally { if (original.isNotEmpty()) vault.save("glm", original) else vault.remove("glm") }
    }
    @Test fun cameraPhotoNormalizesPixels() = runBlocking {
        val files = LocalFiles(context); val uri = files.cameraUri()
        val bitmap = Bitmap.createBitmap(3200, 1000, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.WHITE) }
        context.contentResolver.openOutputStream(uri)!!.use { bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it) }; bitmap.recycle()
        val name = files.importPhoto(uri)
        val normalized = android.graphics.BitmapFactory.decodeFile(files.photo(name).path)
        assertEquals(1600, normalized.width); assertEquals(500, normalized.height); normalized.recycle()
        assertTrue(files.photo(name).length() < 5_000_000)
    }
    @Test fun bundledOcrReadsWithoutPlayServices() = runBlocking {
        val bitmap = Bitmap.createBitmap(1000, 350, Bitmap.Config.ARGB_8888)
        Canvas(bitmap).apply { drawColor(Color.WHITE); drawText("Protein 20 g", 60f, 180f, Paint().apply { color = Color.BLACK; textSize = 82f; isAntiAlias = true }) }
        val file = File(context.cacheDir, "ocr-test.jpg")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it) }; bitmap.recycle()
        val text = recognizeLabel(file)
        assertTrue("Synthetic printed label should be recognized", text.contains("20"))
    }
    @Test fun liveGlmTextAndLabelRequest() = runBlocking {
        assumeTrue(InstrumentationRegistry.getArguments().getString("liveAI") == "true")
        val vault = KeyVault(context); vault.importBundled()
        val key = vault.read("glm"); assertTrue(key.isNotBlank())
        val settings = AISettings()
        val client = AIClient()
        val reply = client.chat(listOf(Message("user", "连接测试，请只回复：连接成功")), "", settings, key)
        assertTrue(reply.isNotBlank())
        val foods = client.analyze(null, "牛奶，实际喝了200mL。每100mL标签：309kJ，蛋白质3.6g，碳水5g，脂肪4.4g。", settings, key)
        assertTrue(foods.isNotEmpty()); assertTrue(foods.all(Food::valid)); assertEquals(7.2, foods.sumOf { it.nutrients.protein }, .5)
    }
}
