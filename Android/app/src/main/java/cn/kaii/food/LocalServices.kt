package cn.kaii.food

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import android.util.Base64
import androidx.core.content.FileProvider
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class KeyVault(private val context: Context) {
    private val prefs = context.getSharedPreferences("credentials", Context.MODE_PRIVATE)
    private fun secret(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("kaii.providers.v1", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("kaii.providers.v1", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized fun read(provider: String): String {
        val raw = prefs.getString(provider, null) ?: return ""
        val parts = raw.split(':'); require(parts.size == 2)
        return Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, secret(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
            String(doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8)
        }
    }
    @Synchronized fun save(provider: String, key: String) {
        require(provider in providers.keys)
        val value = key.trim()
        require(value.length in 16..1024 && value.all { it.code in 33..126 }) { "Key 格式不正确" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, secret()) }
        val encoded = Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(cipher.doFinal(value.toByteArray()), Base64.NO_WRAP)
        check(prefs.edit().putString(provider, encoded).putBoolean("imported.$provider", true).commit())
    }
    @Synchronized fun remove(provider: String) { check(prefs.edit().remove(provider).putBoolean("imported.$provider", true).commit()) }
    @Synchronized fun importBundled() {
        if (!context.assets.list("").orEmpty().contains("PrivateProviders.json")) return
        val raw = context.assets.open("PrivateProviders.json").bufferedReader().use { it.readText() }
        require(raw.length <= 16_384)
        val objectValue = JSONObject(raw)
        for (provider in listOf("glm", "deepseek")) {
            if (prefs.getBoolean("imported.$provider", false)) continue
            if (read(provider).isNotEmpty()) { check(prefs.edit().putBoolean("imported.$provider", true).commit()); continue }
            val key = objectValue.optString(provider)
            if (key.isNotBlank()) save(provider, key)
        }
    }
}

class LocalFiles(private val context: Context) {
    private val diary = AtomicFile(File(context.filesDir, "diary-v1.json"))
    val photoDirectory = File(context.filesDir, "photos").apply { mkdirs() }
    fun read(): Diary = if (!diary.baseFile.exists() && !File(diary.baseFile.path + ".bak").exists()) Diary()
        else Diary.parse(diary.openRead().bufferedReader().use { it.readText() })
    fun write(value: Diary) {
        val stream = diary.startWrite()
        try { stream.write(value.json().toString().toByteArray()); diary.finishWrite(stream) }
        catch (e: Exception) { diary.failWrite(stream); throw e }
    }
    fun photo(name: String): File {
        require(name.matches(Regex("[a-fA-F0-9-]+\\.jpg")))
        return File(photoDirectory, name)
    }
    suspend fun importPhoto(uri: Uri): String = withContext(Dispatchers.IO) {
        require(uri.scheme == "content")
        val source = ImageDecoder.createSource(context.contentResolver, uri)
        val bitmap = ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val scale = minOf(1.0, 1600.0 / maxOf(info.size.width, info.size.height))
            decoder.setTargetSize(maxOf(1, (info.size.width * scale).toInt()), maxOf(1, (info.size.height * scale).toInt()))
        }
        val name = "${UUID.randomUUID()}.jpg"
        // Re-encode pixels only. Original location and other EXIF fields are not copied.
        try {
            val bytes = ByteArrayOutputStream().also { check(bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it)) }.toByteArray()
            require(bytes.size <= 5_000_000) { "照片太大，请换一张" }
            photo(name).writeBytes(bytes)
        } finally { bitmap.recycle() }
        name
    }
    fun cameraUri(): Uri {
        val file = File(context.cacheDir, "camera/${UUID.randomUUID()}.jpg").apply { parentFile?.mkdirs() }
        return FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    }
    fun sharedFile(name: String, contents: String): Uri {
        require(!name.contains('/') && !name.contains(".."))
        val file = File(context.cacheDir, "shared/$name").apply { parentFile?.mkdirs() }
        file.writeText(contents)
        return FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    }
}

suspend fun recognizeLabel(file: File): String = suspendCancellableCoroutine { continuation ->
    val client = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    try {
        val bitmap = android.graphics.BitmapFactory.decodeFile(file.path) ?: error("无法读取照片")
        client.process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { if (continuation.isActive) continuation.resume(it.text) }
            .addOnFailureListener { if (continuation.isActive) continuation.resumeWithException(IllegalStateException("标签识别失败，请换一张更清晰的照片")) }
            .addOnCompleteListener { bitmap.recycle(); client.close() }
    } catch (_: Exception) {
        client.close()
        if (continuation.isActive) continuation.resumeWithException(IllegalStateException("无法读取照片"))
    }
}
