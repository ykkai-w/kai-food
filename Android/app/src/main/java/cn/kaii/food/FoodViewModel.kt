package cn.kaii.food

import android.app.Application
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.time.LocalDate

class FoodViewModel(app: Application, private val savedState: SavedStateHandle) : AndroidViewModel(app) {
    val files = LocalFiles(app)
    private val vault = KeyVault(app)
    private val client = AIClient()
    private val writes = Mutex()
    private val preferences = app.getSharedPreferences("welcome", Application.MODE_PRIVATE)
    var welcomeComplete by mutableStateOf(preferences.getBoolean("complete.v1", false)); private set
    var onboardingBusy by mutableStateOf(false); private set
    var diary by mutableStateOf(Diary()); private set
    var ready by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    var status by mutableStateOf<String?>(null)
    private var methodState by mutableStateOf(savedState.get<String>("mealMethod")?.let { runCatching { MealInputMethod.valueOf(it) }.getOrNull() } ?: MealInputMethod.description)
    var inputMethod: MealInputMethod
        get() = methodState
        set(value) { methodState = value; savedState["mealMethod"] = value.name }
    private var labelState by mutableStateOf(savedState.get<String>("mealLabel") ?: "")
    var labelText: String
        get() = labelState
        set(value) { labelState = value; savedState["mealLabel"] = value }
    private var draftState by mutableStateOf(savedState.get<String>("mealDraft")?.let { raw -> runCatching { Meal.parse(org.json.JSONObject(raw)) }.getOrNull() })
    var draft: Meal?
        get() = draftState
        set(value) {
            if (value?.id != draftState?.id) {
                inputMethod = if (value?.photo.isNullOrBlank()) MealInputMethod.description else MealInputMethod.photo
                labelText = ""
            }
            draftState = value; savedState["mealDraft"] = value?.json()?.toString()
        }
    var busy by mutableStateOf(false); private set
    var chatBusy by mutableStateOf(false); private set
    var saving by mutableStateOf(false); private set
    var glmReady by mutableStateOf(false); private set
    var deepseekReady by mutableStateOf(false); private set
    var kimiReady by mutableStateOf(false); private set
    var chatInput by mutableStateOf("")
    private var chatTask: Job? = null
    init { reload() }
    private fun report(e: Exception, fallback: String) {
        if (e is CancellationException) throw e
        // Never display provider bodies or cryptographic exception details.
        error = when (e) {
            is java.net.SocketTimeoutException -> L10n.text("连接超时，请重试")
            is java.net.UnknownHostException -> L10n.text("网络未连接，请检查网络后重试")
            is IllegalArgumentException, is IllegalStateException -> e.message?.take(180) ?: fallback
            else -> fallback
        }
    }
    fun reload() = viewModelScope.launch {
        try { diary = withContext(Dispatchers.IO) { files.read() }; ready = true }
        catch (_: Exception) { ready = false; error = L10n.text("食记读取失败，原文件已保留，请不要卸载 App。") }
        try {
            withContext(Dispatchers.IO) { vault.importBundled() }
            refreshKeys()
        } catch (_: Exception) { error = L10n.text("AI 配置读取失败，可以在设置重新添加 Key。") }
    }
    private suspend fun update(transform: (Diary) -> Diary) = writes.withLock {
        check(ready) { L10n.text("请先在设置重新读取食记") }
        val next = transform(diary)
        withContext(Dispatchers.IO) { files.write(next) }
        diary = next
    }
    fun startMeal(date: LocalDate, kind: MealKind) { if (ready) draft = Meal(date = date, kind = kind) }
    fun finishWelcome(provider: String? = null, key: String = "") = viewModelScope.launch {
        if (onboardingBusy) return@launch
        onboardingBusy = true
        try {
            if (provider != null) {
                withContext(Dispatchers.IO) { vault.save(provider, key) }
                update { it.copy(settings = it.settings.copy(provider = provider)) }
                refreshKeys()
            }
            withContext(Dispatchers.IO) { check(preferences.edit().putBoolean("complete.v1", true).commit()) }
            welcomeComplete = true
        } catch (e: Exception) { report(e, L10n.text("设置保存失败，请重试")) }
        finally { onboardingBusy = false }
    }
    fun showWelcome() { welcomeComplete = false }
    fun saveFrequent(value: FrequentFood, done: () -> Unit) = viewModelScope.launch {
        try {
            require(value.valid()) { L10n.text("请填写完整的份量和营养值") }
            update { current -> current.copy(frequentFoods = current.frequentFoods.filterNot { it.id == value.id } + value) }
            done()
        } catch (e: Exception) { report(e, L10n.text("常用食物保存失败")) }
    }
    fun deleteFrequent(id: String) = viewModelScope.launch {
        try { update { it.copy(frequentFoods = it.frequentFoods.filterNot { f -> f.id == id }) } }
        catch (e: Exception) { report(e, L10n.text("删除失败，请重试")) }
    }
    fun addFrequent(value: FrequentFood, date: LocalDate, kind: MealKind, done: (Meal) -> Unit) = viewModelScope.launch {
        try {
            val meal = Meal(date = date, kind = kind, items = listOf(value.item()), note = value.portion)
            update { it.copy(meals = it.meals + meal) }
            done(meal)
        } catch (e: Exception) { report(e, L10n.text("添加失败，请重试")) }
    }
    fun saveDraft() = viewModelScope.launch {
        val value = draft ?: return@launch
        if (value.items.isEmpty()) { error = L10n.text("先添加一种食物"); return@launch }
        saving = true
        try { update { it.copy(meals = it.meals.filterNot { m -> m.id == value.id } + value) }; draft = null }
        catch (e: Exception) { report(e, L10n.text("保存失败，请重试")) }
        finally { saving = false }
    }
    fun deleteMeal(id: String) = viewModelScope.launch {
        try { update { it.copy(meals = it.meals.filterNot { meal -> meal.id == id }) } }
        catch (e: Exception) { report(e, L10n.text("删除失败，请重试")) }
    }
    fun addPhoto(uri: Uri) = viewModelScope.launch {
        val draftID = draft?.id ?: return@launch
        busy = true
        try {
            val name = files.importPhoto(uri)
            if (draft?.id == draftID) { draft = draft?.copy(photo = name); labelText = "" }
        } catch (e: Exception) { report(e, L10n.text("照片读取失败，请换一张")) }
        finally { busy = false }
    }
    fun analyze() = viewModelScope.launch {
        if (busy || saving) return@launch
        val value = draft ?: return@launch
        val method = inputMethod
        val settings = diary.settings
        if (!method.canAnalyze(value.photo.isNotBlank(), value.mealDescription, labelText)) return@launch
        val description = if (method == MealInputMethod.label) L10n.text("仅按实际食用量换算营养标签；单位不明时不要编造。\n实际食用：{0}\n标签：{1}", value.mealDescription, labelText) else value.mealDescription
        busy = true
        try {
            val key = withContext(Dispatchers.IO) { vault.read(settings.provider) }
            val bytes = withContext(Dispatchers.IO) { value.photo.takeIf { method == MealInputMethod.photo && it.isNotBlank() }?.let { files.photo(it).readBytes() } }
            val items = client.analyze(bytes, description, settings, key, L10n.responseLanguage)
            if (draft?.id == value.id) {
                if (items.isEmpty()) error = L10n.text("再写一下具体食物和大概份量，然后重新估算。")
                else draft = draft?.withEstimate(items)
            }
        } catch (e: Exception) { report(e, L10n.text("识别失败，请稍后重试")) }
        finally { busy = false }
    }
    fun readLabel() = viewModelScope.launch {
        val value = draft ?: return@launch
        if (value.photo.isEmpty()) { error = L10n.text("先拍摄或选择营养成分表"); return@launch }
        busy = true
        try {
            val text = recognizeLabel(files.photo(value.photo))
            if (draft?.id == value.id) {
                if (text.isBlank()) error = L10n.text("没有识别到文字，请靠近标签再拍一张。")
                else labelText = text
            }
        } catch (e: Exception) { report(e, L10n.text("标签识别失败，请重试")) }
        finally { busy = false }
    }
    fun saveSettings(settings: AISettings) = viewModelScope.launch {
        try { require(settings.valid()) { L10n.text("请检查模型名称和蛋白质目标") }; update { it.copy(settings = settings) }; status = L10n.text("设置已保存") }
        catch (e: Exception) { report(e, L10n.text("设置保存失败")) }
    }
    suspend fun refreshKeys() = withContext(Dispatchers.IO) {
        val glm = vault.read("glm").isNotBlank(); val ds = vault.read("deepseek").isNotBlank(); val kimi = vault.read("kimi").isNotBlank()
        withContext(Dispatchers.Main) { glmReady = glm; deepseekReady = ds; kimiReady = kimi }
    }
    fun saveKey(provider: String, key: String) = viewModelScope.launch {
        try { withContext(Dispatchers.IO) { vault.save(provider, key) }; refreshKeys(); status = L10n.text("Key 已保存") }
        catch (_: Exception) { error = L10n.text("Key 保存失败，请检查后重试。") }
    }
    fun removeKey(provider: String) = viewModelScope.launch {
        try { withContext(Dispatchers.IO) { vault.remove(provider) }; refreshKeys() }
        catch (_: Exception) { error = L10n.text("Key 移除失败，请重试。") }
    }
    fun sendChat(shareRecords: Boolean) {
        val question = chatInput.trim()
        if (chatBusy || question.isEmpty() || !ready) return
        val settings = diary.settings
        chatBusy = true; chatInput = ""
        chatTask = viewModelScope.launch {
            try {
                val key = withContext(Dispatchers.IO) { vault.read(settings.provider) }
                val history = diary.messages + Message("user", question)
                val context = if (shareRecords) exportMarkdown(diary.meals, LocalDate.now().minusDays(6), LocalDate.now()) else L10n.text("未分享食记")
                val reply = client.chat(history, context, settings, key, L10n.responseLanguage)
                update { it.copy(messages = (history + Message("assistant", reply)).takeLast(200)) }
            } catch (e: Exception) {
                if (chatInput.isBlank()) chatInput = question
                if (e !is CancellationException) report(e, L10n.text("发送失败，请重试"))
            } finally { chatBusy = false }
        }
    }
    fun stopChat() { chatTask?.cancel(); chatBusy = false }
    fun clearChat() = viewModelScope.launch {
        if (chatBusy) return@launch
        try { update { it.copy(messages = emptyList()) } } catch (e: Exception) { report(e, L10n.text("清空失败，请重试")) }
    }
    fun importBackup(uri: Uri) = viewModelScope.launch {
        try {
            val backup = withContext(Dispatchers.IO) {
                val bytes = getApplication<Application>().contentResolver.openInputStream(uri)!!.use { it.readLimitedBytes(20_000_001) }
                require(bytes.size <= 20_000_000) { L10n.text("备份文件过大") }
                Diary.parse(String(bytes, Charsets.UTF_8))
            }
            update { current -> current.copy(meals = (current.meals + backup.meals.map { it.copy(photo = "") }).distinctBy { it.id }, frequentFoods = (current.frequentFoods + backup.frequentFoods).distinctBy { it.id }) }
            status = L10n.text("食记已合并导入")
        } catch (e: Exception) { report(e, L10n.text("备份无法读取，现有记录未更改")) }
    }
}
