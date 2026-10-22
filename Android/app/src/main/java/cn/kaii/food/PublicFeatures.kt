package cn.kaii.food

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import java.time.LocalDate

@Composable fun WelcomeScreen(vm: FoodViewModel) {
    val context = LocalContext.current
    var provider by rememberSaveable { mutableStateOf("glm") }
    var key by remember { mutableStateOf("") }
    var showCosts by rememberSaveable { mutableStateOf(false) }
    Surface(Modifier.fillMaxSize()) {
        Column(Modifier.safeDrawingPadding()) {
            PageColumn {
                LanguagePicker()
                Text(L10n.text("kaii 食记"), fontSize = 38.sp, fontFamily = FontFamily.Serif, color = MaterialTheme.colorScheme.primary)
                AssetImage("MealHero", Modifier.fillMaxWidth().height(140.dp).clip(RoundedCornerShape(16.dp)))
                Text(L10n.text("把每天吃的，随手记下来。"), fontSize = 25.sp, fontWeight = FontWeight.Medium)
                Text(L10n.text("拍照、写几句话，或者直接添加常吃的食物。记录可以一键导出，交给你自己的 AI 看看。"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(L10n.text("选一家 AI 就够了"), fontSize = 21.sp, fontWeight = FontWeight.SemiBold)
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    providers.forEach { (id, title) -> FilterChip(provider == id, { provider = id }, enabled = !vm.onboardingBusy, label = { Text(title) }) }
                }
                Text(L10n.text("推荐先用 GLM，已配好日常记餐模型。DeepSeek 和 Kimi 也可用于图文记餐与对话。"), fontSize = 15.sp)
                TextButton(onClick = { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(providerKeyURL(provider)))) }.onFailure { vm.error = L10n.text("请用浏览器打开对应 AI 开放平台。") } }) { Text(L10n.text("去 {0} 获取 API Key", providers[provider])) }
                OutlinedTextField(key, { key = it }, Modifier.fillMaxWidth(), label = { Text(L10n.text("粘贴你的 API Key")) }, visualTransformation = PasswordVisualTransformation(), singleLine = true, enabled = !vm.onboardingBusy)
                Text(L10n.text("Key 保存在本机，调用费用由你的 AI 账户支付。每次发送前会确认分享的内容。"), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = { showCosts = !showCosts }) { Text(L10n.text("用 AI 要花多少 · GLM 示例约 0.00135～0.0025 元/次")) }
                if (showCosts) {
                    Text(L10n.text("以默认 GLM 模型算一笔小账，这两个例子都不到一分钱。"), fontSize = 15.sp)
                    Text(L10n.text("文字问答约 0.0025 元\nGLM 4.7 FlashX，假设输入 2,000、输出 500 tokens。\n\n照片识别约 0.00135 元\nGLM 4.6V FlashX，假设图片与文字合计输入 4,000、输出 500 tokens。"), fontSize = 15.sp)
                    Text(L10n.text("各调用 100 次，合计约 0.385 元。输入包含问题、照片及附带的食记和对话，实际费用随用量变化，按服务商账单结算。"), fontSize = 13.sp)
                    Text(L10n.text("按 2026 年 10 月 22 日官方标准价计算，输入均低于 32K，按无缓存命中计算。文字输入/输出每百万 tokens 为 0.5/3 元，视觉为 0.15/1.5 元。"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    TextButton(onClick = { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://docs.bigmodel.cn/cn/guide/start/pricing"))) }.onFailure { vm.error = L10n.text("请用浏览器打开 GLM 官方价格页。") } }) { Text(L10n.text("查看 GLM 官方价格")) }
                }
                PrimaryButton(if (vm.onboardingBusy) L10n.text("正在保存…") else L10n.text("保存并开始"), Modifier.fillMaxWidth(), key.isNotBlank() && vm.ready && !vm.onboardingBusy) { vm.finishWelcome(provider, key) }
                TextButton(onClick = { key = ""; vm.finishWelcome() }, Modifier.fillMaxWidth(), enabled = !vm.onboardingBusy) { Text(L10n.text("先逛逛，稍后设置")) }
                Text(L10n.text("跳过后可以手动记餐、使用常用食物和导出记录。AI 设置随时可改。"), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable fun LanguagePicker() {
    var expanded by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(L10n.text("语言 / Language"), Modifier.weight(1f))
        Box {
            TextButton(onClick = { expanded = true }) { Text(if (L10n.choice == "system") L10n.text("跟随系统") else L10n.choices.getValue(L10n.choice)) }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                L10n.choices.forEach { (id, name) ->
                    DropdownMenuItem(text = { Text(if (id == "system") L10n.text("跟随系统") else name) }, onClick = { L10n.select(id); expanded = false })
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun FrequentFoodsDialog(vm: FoodViewModel, initialDate: LocalDate, onDismiss: () -> Unit, onChoose: ((Food) -> Unit)? = null) {
    val context = LocalContext.current
    var dateText by rememberSaveable { mutableStateOf(initialDate.toString()) }
    var kind by rememberSaveable { mutableStateOf(MealKind.breakfast) }
    var adding by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<FrequentFood?>(null) }
    var deleting by remember { mutableStateOf<FrequentFood?>(null) }
    var lastAdded by remember { mutableStateOf<Meal?>(null) }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(topBar = { TopAppBar(title = { Text(L10n.text("常用食物")) }, navigationIcon = { IconButton(onClick = onDismiss) { Icon(Icons.Outlined.Close, L10n.text("完成")) } }) }) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                if (onChoose == null) {
                    TextButton(onClick = { showDate(context, LocalDate.parse(dateText)) { dateText = it.toString() } }) { Icon(Icons.Outlined.CalendarMonth, null); Text("  $dateText") }
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) { MealKind.entries.forEach { value -> FilterChip(kind == value, { kind = value }, label = { Text(value.title) }) } }
                }
                if (vm.diary.frequentFoods.isEmpty()) {
                    Text(L10n.text("常吃的，存一份就好。"), fontSize = 24.sp, fontWeight = FontWeight.Medium)
                    Text(L10n.text("比如一勺蛋白粉、两个鸡蛋。填好品牌、份量和营养，下次直接添加。"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                vm.diary.frequentFoods.forEach { value ->
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onClick = { editing = value }, Modifier.weight(1f)) {
                            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(value.food.name, fontSize = 19.sp, color = MaterialTheme.colorScheme.onSurface)
                                Text("${value.portion} · ${value.food.grams.pretty()} ${value.food.unit}", fontSize = 14.sp)
                                Text(L10n.text("{0} kcal · 蛋白质 {1} g", value.food.nutrients.kcal.pretty(), value.food.nutrients.protein.pretty()), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        IconButton(onClick = { if (onChoose != null) onChoose(value.item()) else vm.addFrequent(value, LocalDate.parse(dateText), kind) { lastAdded = it } }) { Icon(Icons.Outlined.AddCircleOutline, L10n.text("添加{0}", value.food.name)) }
                        IconButton(onClick = { deleting = value }) { Icon(Icons.Outlined.DeleteOutline, L10n.text("删除{0}", value.food.name)) }
                    }
                    HorizontalDivider()
                }
                OutlinedButton(onClick = { adding = true }, Modifier.fillMaxWidth().heightIn(min = 52.dp)) { Icon(Icons.Outlined.Add, null); Text(L10n.text("  新建常用食物")) }
                lastAdded?.let { meal -> Row(verticalAlignment = Alignment.CenterVertically) { Text(L10n.text("已加入{0} · {1}", meal.kind.title, meal.items.first().name), Modifier.weight(1f)); TextButton(onClick = { vm.deleteMeal(meal.id); lastAdded = null }) { Text(L10n.text("撤销")) } } }
            }
        }
        if (adding || editing != null) FrequentFoodDialog(vm, existing = editing, onDismiss = { adding = false; editing = null })
        deleting?.let { value -> AlertDialog(onDismissRequest = { deleting = null }, title = { Text(L10n.text("删除这个常用食物？")) }, text = { Text(L10n.text("已保存的食记会保留。")) }, confirmButton = { TextButton(onClick = { vm.deleteFrequent(value.id); deleting = null }) { Text(L10n.text("删除")) } }, dismissButton = { TextButton(onClick = { deleting = null }) { Text(L10n.text("取消")) } }) }
    }
}

@Composable fun FrequentFoodDialog(vm: FoodViewModel, existing: FrequentFood? = null, initialFood: Food? = null, onDismiss: () -> Unit) {
    var food by remember { mutableStateOf(existing?.food ?: initialFood) }
    var portion by remember { mutableStateOf(existing?.portion ?: L10n.text("1 份")) }
    var editFood by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    AlertDialog(onDismissRequest = { if (!saving) onDismiss() }, title = { Text(if (existing == null) L10n.text("存为常用食物") else L10n.text("编辑常用食物")) }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            OutlinedTextField(portion, { portion = it.take(80) }, Modifier.fillMaxWidth(), label = { Text(L10n.text("固定份量，如 1 勺、2 个")) }, enabled = !saving)
            Text(L10n.text("填写这份食物的重量和营养。包装食品可以按标签换算。"), fontSize = 14.sp)
            food?.let { Text(it.name, fontSize = 19.sp, fontWeight = FontWeight.Medium); Text("${it.grams.pretty()} ${it.unit} · ${it.nutrients.kcal.pretty()} kcal") }
            TextButton(onClick = { editFood = true }, enabled = !saving) { Text(if (food == null) L10n.text("填写食物与营养") else L10n.text("编辑食物与营养")) }
            vm.error?.let { Text(it, color = MaterialTheme.colorScheme.error); TextButton(onClick = { vm.error = null; saving = false }) { Text(L10n.text("重试")) } }
        }
    }, confirmButton = { TextButton(onClick = { food?.let { saving = true; vm.saveFrequent(FrequentFood(existing?.id ?: java.util.UUID.randomUUID().toString(), it, portion.trim())) { onDismiss() } } }, enabled = food != null && portion.isNotBlank() && !saving) { Text(if (saving) L10n.text("保存中…") else L10n.text("保存")) } }, dismissButton = { TextButton(onClick = onDismiss, enabled = !saving) { Text(L10n.text("取消")) } })
    if (editFood) FoodDialog(food, onDismiss = { editFood = false }) { food = it; editFood = false }
}
