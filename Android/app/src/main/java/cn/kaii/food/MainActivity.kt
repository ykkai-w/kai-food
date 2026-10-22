package cn.kaii.food

import android.app.DatePickerDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.viewmodel.compose.viewModel
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val Blue = Color(0xFF034694)
private val Paper = Color(0xFFF7F9FC)
private val Round = RoundedCornerShape(22.dp)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        L10n.initialize(applicationContext)
        setContent { KaiiTheme { FoodApp() } }
    }
}
@Composable fun KaiiTheme(content: @Composable () -> Unit) {
    val colors = if (isSystemInDarkTheme()) darkColorScheme(primary = Color(0xFF9BC5FF), background = Color(0xFF101820), surface = Color(0xFF18222F))
        else lightColorScheme(primary = Blue, background = Paper, surface = Color.White, onSurface = Color(0xFF202830), secondaryContainer = Color(0xFFEAF0FA))
    MaterialTheme(colorScheme = colors, typography = Typography(bodyLarge = androidx.compose.ui.text.TextStyle(fontSize = 17.sp, lineHeight = 26.sp)), content = content)
}

@Composable private fun FoodApp(vm: FoodViewModel = viewModel()) {
    val baseContext = LocalContext.current
    val localizedContext = remember(L10n.language, baseContext) {
        val configuration = android.content.res.Configuration(baseContext.resources.configuration)
        configuration.setLocale(L10n.locale)
        android.view.ContextThemeWrapper(baseContext, baseContext.theme).apply {
            applyOverrideConfiguration(configuration)
        }
    }
    CompositionLocalProvider(LocalContext provides localizedContext) {
        FoodContent(vm)
    }
}

@Composable private fun FoodContent(vm: FoodViewModel) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val tabs = listOf(L10n.text("食记"), L10n.text("问 AI"), L10n.text("导出"), L10n.text("设置"))
    val icons = listOf(Icons.AutoMirrored.Outlined.MenuBook, Icons.AutoMirrored.Outlined.Chat, Icons.Outlined.IosShare, Icons.Outlined.Tune)
    if (!vm.welcomeComplete) WelcomeScreen(vm) else Scaffold(containerColor = MaterialTheme.colorScheme.background, bottomBar = {
        NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
            tabs.forEachIndexed { index, name -> NavigationBarItem(selected = tab == index, onClick = { tab = index },
                icon = { Icon(icons[index], name) }, label = { Text(name, fontSize = 14.sp) }) }
        }
    }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (tab) { 0 -> DiaryScreen(vm); 1 -> ChatScreen(vm); 2 -> ExportScreen(vm); 3 -> SettingsScreen(vm) }
        }
    }
    if (vm.draft != null) MealEditor(vm)
    vm.error?.let { message -> AlertDialog(onDismissRequest = { vm.error = null }, title = { Text(L10n.text("操作未完成")) }, text = { Text(L10n.text(message)) }, confirmButton = { TextButton(onClick = { vm.error = null }) { Text(L10n.text("好")) } }) }
    vm.status?.let { message -> AlertDialog(onDismissRequest = { vm.status = null }, text = { Text(message) }, confirmButton = { TextButton(onClick = { vm.status = null }) { Text(L10n.text("好")) } }) }
}

@Composable fun AssetImage(name: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val bitmap = remember(name) { runCatching { context.assets.open("$name.jpg").use { BitmapFactory.decodeStream(it)?.asImageBitmap() } }.getOrNull() }
    bitmap?.let { Image(it, null, modifier, contentScale = ContentScale.Crop) }
}
@Composable fun PageColumn(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 18.dp), verticalArrangement = Arrangement.spacedBy(22.dp), content = content)
}
@Composable private fun Heading(title: String, subtitle: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, fontSize = 30.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
        subtitle?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}
@Composable fun PrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, action: () -> Unit) {
    Button(action, modifier.heightIn(min = 54.dp), enabled = enabled, shape = RoundedCornerShape(16.dp)) { Text(text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold) }
}
fun showDate(context: Context, initial: LocalDate, action: (LocalDate) -> Unit) {
    DatePickerDialog(context, { _, y, m, d -> action(LocalDate.of(y, m + 1, d)) }, initial.year, initial.monthValue - 1, initial.dayOfMonth).show()
}

@Composable private fun DiaryScreen(vm: FoodViewModel) {
    var dateText by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    val date = LocalDate.parse(dateText)
    val context = LocalContext.current
    val meals = vm.diary.meals.filter { it.date == date }.sortedBy { it.kind.ordinal }
    val total = meals.fold(Nutrients()) { sum, meal -> sum + meal.total }
    var deleting by remember { mutableStateOf<Meal?>(null) }
    var showFrequent by remember { mutableStateOf(false) }
    PageColumn {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("kaii", fontSize = 35.sp, fontFamily = FontFamily.Serif, color = MaterialTheme.colorScheme.primary)
            Text(L10n.text("  食记"), fontSize = 22.sp, color = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.weight(1f))
            Image(painterResource(R.drawable.brand_icon), L10n.text("kaii 咖啡哑铃图标"), Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)))
        }
        AssetImage("MealHero", Modifier.fillMaxWidth().height(150.dp).clip(Round))
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { showDate(context, date) { dateText = it.toString() } }) { Text(date.format(DateTimeFormatter.ofPattern(L10n.text("yyyy年 M月"), L10n.locale)), fontSize = 18.sp); Icon(Icons.Outlined.ExpandMore, L10n.text("选择日期")) }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { dateText = LocalDate.now().toString() }) { Text(L10n.text("今天")) }
            }
            val monday = date.minusDays((date.dayOfWeek.value - 1).toLong())
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                repeat(7) { i ->
                    val day = monday.plusDays(i.toLong()); val selected = day == date
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).background(if (selected) Blue else Color.Transparent)
                        .clickable { dateText = day.toString() }.padding(vertical = 11.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(listOf(L10n.text("一"), L10n.text("二"), L10n.text("三"), L10n.text("四"), L10n.text("五"), L10n.text("六"), L10n.text("日"))[i], fontSize = 12.sp, color = if (selected) Color.White.copy(alpha = .8f) else MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(7.dp)); Text(day.dayOfMonth.toString(), fontSize = 19.sp, fontWeight = FontWeight.Medium, color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface)
                    }
                }
            }
        }
        if (!vm.ready) { Text(L10n.text("正在准备食记。如读取失败，可到设置重试。")); return@PageColumn }
        if (meals.isNotEmpty()) {
            Text(L10n.text("已记录合计"), color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(verticalAlignment = Alignment.Bottom) { Text(total.kcal.pretty(), fontSize = 48.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.primary); Text("  kcal", Modifier.padding(bottom = 7.dp)) }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                listOf(L10n.text("蛋白质") to total.protein, L10n.text("碳水") to total.carbs, L10n.text("脂肪") to total.fat).forEach { (name, number) ->
                    Column { Text(name, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant); Text("${number.pretty()} g", fontSize = 21.sp, fontWeight = FontWeight.SemiBold) }
                }
            }
        } else { Heading(if (date == LocalDate.now()) L10n.text("今天吃了什么？") else L10n.text("这天吃了什么？"), L10n.text("选一餐，写下吃了什么，或拍张照片。")) }
        val goal = vm.diary.settings.proteinGoal
        if (goal > 0) {
            Surface(shape = Round, color = MaterialTheme.colorScheme.secondaryContainer) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(Modifier.fillMaxWidth()) { Text(L10n.text("今日蛋白质"), fontWeight = FontWeight.Medium); Spacer(Modifier.weight(1f)); Text("${total.protein.pretty()} / ${goal.pretty()} g") }
                    LinearProgressIndicator(progress = { (total.protein / goal).toFloat().coerceIn(0f, 1f) }, Modifier.fillMaxWidth())
                }
            }
        }
        meals.forEach { meal ->
            Surface(shape = Round, onClick = { vm.draft = meal }) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) { Text(meal.kind.title, fontSize = 20.sp, fontWeight = FontWeight.SemiBold); Spacer(Modifier.weight(1f)); IconButton(onClick = { deleting = meal }) { Icon(Icons.Outlined.DeleteOutline, L10n.text("删除这餐")) } }
                    meal.items.forEach { f -> Row(Modifier.fillMaxWidth()) { Text(f.name, Modifier.weight(1f)); Text("${f.grams.pretty()} ${f.unit}", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
                    Text(L10n.text("{0} kcal · 蛋白质 {1} g", meal.total.kcal.pretty(), meal.total.protein.pretty()), color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        TextButton(onClick = { showFrequent = true }, modifier = Modifier.fillMaxWidth().heightIn(min = 58.dp)) {
            Icon(Icons.Outlined.BookmarkBorder, null); Spacer(Modifier.width(12.dp)); Text(L10n.text("常用食物"), fontSize = 20.sp); Spacer(Modifier.weight(1f)); Icon(Icons.AutoMirrored.Outlined.ArrowForward, L10n.text("打开常用食物"))
        }
        Text(L10n.text("记下一餐"), fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
        MealKind.entries.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                row.forEach { kind ->
                    Surface(onClick = { vm.startMeal(date, kind) }, Modifier.weight(1f), shape = Round) {
                        Column { AssetImage(kind.asset, Modifier.fillMaxWidth().height(100.dp)); Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) { Text(kind.title, fontSize = 18.sp, fontWeight = FontWeight.Medium); Spacer(Modifier.weight(1f)); Icon(Icons.Outlined.Add, L10n.text("添加{0}", kind.title), Modifier.size(20.dp)) } }
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
    deleting?.let { meal -> AlertDialog(onDismissRequest = { deleting = null }, title = { Text(L10n.text("删除这条食记？")) }, text = { Text("${meal.date} · ${meal.kind.title}") }, confirmButton = { TextButton(onClick = { vm.deleteMeal(meal.id); deleting = null }) { Text(L10n.text("删除")) } }, dismissButton = { TextButton(onClick = { deleting = null }) { Text(L10n.text("取消")) } }) }
    if (showFrequent) FrequentFoodsDialog(vm, date, onDismiss = { showFrequent = false })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun MealEditor(vm: FoodViewModel) {
    val meal = vm.draft ?: return
    val method = vm.inputMethod
    val context = LocalContext.current
    var cameraUriText by rememberSaveable { mutableStateOf("") }
    var foodEdit by remember { mutableStateOf<Food?>(null) }
    var adding by remember { mutableStateOf(false) }
    var confirmAI by remember { mutableStateOf(false) }
    var confirmClose by remember { mutableStateOf(false) }
    var showFrequent by remember { mutableStateOf(false) }
    var favoriteFood by remember { mutableStateOf<Food?>(null) }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { it?.let(vm::addPhoto) }
    val capture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success -> if (success && cameraUriText.isNotEmpty()) vm.addPhoto(Uri.parse(cameraUriText)) }
    Dialog(onDismissRequest = { if (!vm.busy && !vm.saving) confirmClose = true }, properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false)) {
        Scaffold(topBar = { TopAppBar(title = { Text(L10n.text("记{0}", meal.kind.title)) }, navigationIcon = { IconButton(onClick = { confirmClose = true }, enabled = !vm.busy && !vm.saving) { Icon(Icons.Outlined.Close, L10n.text("关闭")) } }) },
            bottomBar = { Surface { PrimaryButton(if (vm.saving) L10n.text("正在保存…") else L10n.text("保存这餐"), Modifier.fillMaxWidth().navigationBarsPadding().padding(18.dp), !vm.busy && !vm.saving && meal.items.isNotEmpty()) { vm.saveDraft() } } }) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                TextButton(onClick = { showDate(context, meal.date) { vm.draft = vm.draft?.copy(date = it) } }) { Icon(Icons.Outlined.CalendarMonth, null); Text("  ${meal.date}", fontSize = 18.sp) }
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) { MealKind.entries.forEach { kind -> FilterChip(selected = meal.kind == kind, onClick = { vm.draft = vm.draft?.copy(kind = kind) }, label = { Text(kind.title) }) } }
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    MealInputMethod.entries.forEach { entry ->
                        FilterChip(selected = method == entry, onClick = { vm.inputMethod = entry }, enabled = !vm.busy && !vm.saving, label = { Text(entry.title) })
                    }
                }
                if (method == MealInputMethod.description) {
                    Text(L10n.text("回想一下，这餐吃了什么？"), fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
                    OutlinedTextField(meal.mealDescription, { vm.draft = vm.draft?.copy(mealDescription = it.take(12_000)) }, Modifier.fillMaxWidth(),
                        label = { Text(L10n.text("餐食描述")) }, placeholder = { Text(L10n.text("比如：中午吃了一碗米饭、一个卤鸡腿、半盘炒青菜。")) }, minLines = 4, maxLines = 10, enabled = !vm.busy && !vm.saving)
                    Text(L10n.text("一碗、半份、几个都可以，记得多少就写多少。"), fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                if (meal.photo.isNotEmpty()) {
                    val bitmap = remember(meal.photo) { runCatching { BitmapFactory.decodeFile(vm.files.photo(meal.photo).path)?.asImageBitmap() }.getOrNull() }
                    bitmap?.let { Image(it, L10n.text("这餐照片"), Modifier.fillMaxWidth().height(210.dp).clip(Round), contentScale = ContentScale.Crop) }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedButton(onClick = { try { val uri = vm.files.cameraUri(); cameraUriText = uri.toString(); capture.launch(uri) } catch (_: Exception) { vm.error = L10n.text("没有可用相机，请改选照片。") } }, Modifier.weight(1f).heightIn(min = 52.dp), enabled = !vm.busy) { Icon(Icons.Outlined.PhotoCamera, null); Text(L10n.text("  拍照")) }
                    OutlinedButton(onClick = { pick.launch("image/*") }, Modifier.weight(1f).heightIn(min = 52.dp), enabled = !vm.busy) { Icon(Icons.Outlined.PhotoLibrary, null); Text(L10n.text("  相册")) }
                }
                if (method == MealInputMethod.label) {
                    OutlinedButton(onClick = vm::readLabel, Modifier.fillMaxWidth().heightIn(min = 54.dp), enabled = !vm.busy && meal.photo.isNotBlank()) { Text(L10n.text("扫描标签文字")) }
                    OutlinedTextField(vm.labelText, { vm.labelText = it.take(12_000) }, Modifier.fillMaxWidth(), label = { Text(L10n.text("标签文字")) }, minLines = 3, maxLines = 8, enabled = !vm.busy)
                    Text(L10n.text("本机识别，可直接修改文字。"), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                OutlinedTextField(meal.mealDescription, { vm.draft = vm.draft?.copy(mealDescription = it.take(12_000)) }, Modifier.fillMaxWidth(),
                    label = { Text(if (method == MealInputMethod.label) L10n.text("实际食用量，如 200 mL 牛奶") else L10n.text("补充份量、做法或酱汁（选填）")) }, minLines = 2, maxLines = 5, enabled = !vm.busy)
                }
                PrimaryButton(if (vm.busy) L10n.text("正在估算…") else when (method) {
                    MealInputMethod.description -> L10n.text("AI 估算这一餐")
                    MealInputMethod.photo -> L10n.text("识别这一餐")
                    MealInputMethod.label -> L10n.text("按标签换算")
                }, Modifier.fillMaxWidth(), !vm.busy && !vm.saving && method.canAnalyze(meal.photo.isNotBlank(), meal.mealDescription, vm.labelText)) { confirmAI = true }
                if (vm.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                Text(L10n.text("当前 AI · {0}", providers[vm.diary.settings.provider]), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = { showFrequent = true }, enabled = !vm.busy && !vm.saving) { Icon(Icons.Outlined.BookmarkBorder, null); Text(L10n.text("  从常用食物添加")) }
                Row(verticalAlignment = Alignment.CenterVertically) { Text(if (meal.items.isEmpty()) L10n.text("这餐的食物") else L10n.text("确认这餐的食物"), fontSize = 21.sp, fontWeight = FontWeight.SemiBold); Spacer(Modifier.weight(1f)); TextButton(onClick = { adding = true }, enabled = !vm.busy && !vm.saving) { Text(L10n.text("手动添加")) } }
                meal.items.forEach { food ->
                    Surface(onClick = { if (!vm.busy) foodEdit = food }, shape = Round) {
                        Column(Modifier.padding(17.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) { Text(food.name, Modifier.weight(1f), fontSize = 19.sp, fontWeight = FontWeight.Medium); IconButton(onClick = { vm.draft = vm.draft?.copy(items = meal.items.filterNot { it.id == food.id }) }, enabled = !vm.busy) { Icon(Icons.Outlined.RemoveCircleOutline, L10n.text("移除{0}", food.name)) } }
                            Text(L10n.text("{0} {1} · {2} kcal · 蛋白质 {3} g", food.grams.pretty(), food.unit, food.nutrients.kcal.pretty(), food.nutrients.protein.pretty()))
                            Text(L10n.text(food.source) + if (food.uncertainty.isBlank()) "" else " · ${food.uncertainty}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            TextButton(onClick = { favoriteFood = food }, enabled = !vm.busy && !vm.saving) { Text(L10n.text("存为常用食物")) }
                        }
                    }
                }
                if (meal.items.isNotEmpty()) Text(L10n.text("合计 {0} kcal · 蛋白质 {1} g", meal.total.kcal.pretty(), meal.total.protein.pretty()), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                OutlinedTextField(meal.note, { vm.draft = vm.draft?.copy(note = it.take(12_000)) }, Modifier.fillMaxWidth(), label = { Text(L10n.text("备注（选填）")) }, maxLines = 4, enabled = !vm.busy && !vm.saving)
                Spacer(Modifier.height(30.dp))
            }
        }
        if (adding || foodEdit != null) FoodDialog(foodEdit, onDismiss = { adding = false; foodEdit = null }) { food ->
            vm.draft = vm.draft?.copy(items = meal.items.filterNot { it.id == food.id } + food); adding = false; foodEdit = null
        }
        if (confirmAI) AlertDialog(onDismissRequest = { confirmAI = false }, title = { Text(if (meal.items.isEmpty()) L10n.text("生成营养草稿？") else L10n.text("重新估算这餐？")) }, text = {
            val input = when (method) { MealInputMethod.description -> L10n.text("这段餐食描述"); MealInputMethod.photo -> L10n.text("所选照片和补充文字"); MealInputMethod.label -> L10n.text("标签文字及食用量") }
            Text(L10n.text("将{0}发送给 {1}。", input, providers[vm.diary.settings.provider]) + if (meal.items.isEmpty()) L10n.text("估算后可修改份量，再保存。") else L10n.text("新结果会替换当前食物列表，保存前可修改。"))
        }, confirmButton = { TextButton(onClick = { confirmAI = false; vm.analyze() }) { Text(if (meal.items.isEmpty()) L10n.text("开始估算") else L10n.text("重新估算")) } }, dismissButton = { TextButton(onClick = { confirmAI = false }) { Text(L10n.text("取消")) } })
        if (confirmClose) AlertDialog(onDismissRequest = { confirmClose = false }, title = { Text(L10n.text("退出这次编辑？")) }, text = { Text(L10n.text("尚未保存的修改会丢失。")) }, confirmButton = { TextButton(onClick = { vm.draft = null }) { Text(L10n.text("退出")) } }, dismissButton = { TextButton(onClick = { confirmClose = false }) { Text(L10n.text("继续编辑")) } })
        if (showFrequent) FrequentFoodsDialog(vm, meal.date, onDismiss = { showFrequent = false }, onChoose = { food -> vm.draft = vm.draft?.let { it.copy(items = it.items + food) }; showFrequent = false })
        favoriteFood?.let { food -> FrequentFoodDialog(vm, initialFood = food, onDismiss = { favoriteFood = null }) }
    }
}

@Composable fun FoodDialog(existing: Food?, onDismiss: () -> Unit, onSave: (Food) -> Unit) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var grams by remember { mutableStateOf(existing?.grams?.pretty() ?: "100") }
    var unit by remember { mutableStateOf(existing?.unit ?: "g") }
    var kcal by remember { mutableStateOf(existing?.nutrients?.kcal?.pretty() ?: "") }
    var protein by remember { mutableStateOf(existing?.nutrients?.protein?.pretty() ?: "") }
    var carbs by remember { mutableStateOf(existing?.nutrients?.carbs?.pretty() ?: "") }
    var fat by remember { mutableStateOf(existing?.nutrients?.fat?.pretty() ?: "") }
    var per100 by remember { mutableStateOf(false) }; var kilojoules by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) L10n.text("添加食物") else L10n.text("修改食物")) }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(name, { name = it.take(200) }, label = { Text(L10n.text("食物名称")) }, singleLine = true)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { NumberField(L10n.text("食用份量"), grams, { grams = it }, Modifier.weight(1f)); FilterChip(unit == "mL", { unit = if (unit == "g") "mL" else "g" }, label = { Text(unit) }) }
            if (existing != null) TextButton(onClick = {
                runCatching { existing.resized(grams.toDouble()) }.onSuccess {
                    kcal = it.nutrients.kcal.pretty(); protein = it.nutrients.protein.pretty(); carbs = it.nutrients.carbs.pretty(); fat = it.nutrients.fat.pretty()
                    unit = it.unit; per100 = false; kilojoules = false; error = null
                }.onFailure { error = L10n.text("请填写合理的食用量。") }
            }) { Text(L10n.text("按新份量换算营养")) }
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(per100, { per100 = it }); Text(L10n.text("按标签每 100 {0} 填写", unit)) }
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(kilojoules, { kilojoules = it }); Text(L10n.text("标签能量是千焦 kJ")) }
            NumberField(if (kilojoules) L10n.text("能量 · kJ") else L10n.text("能量 · kcal"), kcal, { kcal = it })
            NumberField(L10n.text("蛋白质 · g"), protein, { protein = it }); NumberField(L10n.text("碳水 · g"), carbs, { carbs = it }); NumberField(L10n.text("脂肪 · g"), fat, { fat = it })
            Text(if (per100) L10n.text("保存时按实际食用份量换算。") else L10n.text("营养填写整份食物的数值。"), fontSize = 13.sp)
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }, confirmButton = { TextButton(onClick = {
        try {
            val amount = grams.toDouble(); val energy = kcal.toDouble() / if (kilojoules) 4.184 else 1.0
            val nutrients = Nutrients(energy, protein.toDouble(), carbs.toDouble(), fat.toDouble()).scaled(if (per100) amount / 100 else 1.0)
            val food = Food(id = existing?.id ?: java.util.UUID.randomUUID().toString(), name = name.trim(), grams = amount, unit = unit, nutrients = nutrients, source = if (per100) "标签换算" else existing?.source ?: "手动", uncertainty = existing?.uncertainty ?: "")
            require(food.valid()); onSave(food)
        } catch (_: Exception) { error = L10n.text("请填写完整、合理的份量和营养数值。") }
    }) { Text(L10n.text("保存")) } }, dismissButton = { TextButton(onClick = onDismiss) { Text(L10n.text("取消")) } })
}
@Composable private fun NumberField(label: String, value: String, change: (String) -> Unit, modifier: Modifier = Modifier.fillMaxWidth()) {
    OutlinedTextField(value, { if (it.length <= 10) change(it) }, modifier, label = { Text(label) }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
}

@Composable private fun ChatScreen(vm: FoodViewModel) {
    var modelMenu by remember { mutableStateOf(false) }
    var shareRecords by rememberSaveable { mutableStateOf(false) }
    var confirmSend by remember { mutableStateOf(false) }
    var confirmClear by remember { mutableStateOf(false) }
    val scroll = rememberScrollState()
    LaunchedEffect(vm.diary.messages.size, vm.chatBusy) { if (vm.diary.messages.isNotEmpty()) scroll.animateScrollTo(scroll.maxValue) }
    Column(Modifier.fillMaxSize().imePadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(L10n.text("问 AI"), Modifier.weight(1f), fontSize = 28.sp, fontWeight = FontWeight.SemiBold)
            Box {
                TextButton(onClick = { modelMenu = true }, enabled = !vm.chatBusy) { Text(providers[vm.diary.settings.provider] ?: "AI"); Icon(Icons.Outlined.ExpandMore, L10n.text("切换模型")) }
                DropdownMenu(expanded = modelMenu, onDismissRequest = { modelMenu = false }) {
                    providers.forEach { (id, title) -> DropdownMenuItem(text = { Column { Text(title); Text(vm.diary.settings.model(id), fontSize = 12.sp) } }, onClick = { vm.saveSettings(vm.diary.settings.copy(provider = id)); modelMenu = false }) }
                }
            }
            if (vm.diary.messages.isNotEmpty()) IconButton(onClick = { confirmClear = true }, enabled = !vm.chatBusy) { Icon(Icons.Outlined.DeleteOutline, L10n.text("清空对话")) }
        }
        Column(Modifier.weight(1f).verticalScroll(scroll).padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            if (vm.diary.messages.isEmpty()) {
                Surface(color = Blue, shape = RoundedCornerShape(26.dp)) {
                    Column(Modifier.fillMaxWidth().padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Text(L10n.text("吃饭这件小事，\n一起想一想。"), color = Color.White, fontSize = 28.sp, lineHeight = 39.sp, fontWeight = FontWeight.Medium)
                        Text(L10n.text("搭配、食材、下一餐，都可以问。"), color = Color.White.copy(alpha = .8f), fontSize = 15.sp)
                    }
                }
                Spacer(Modifier.height(4.dp)); Text(L10n.text("也可以聊聊"), fontSize = 16.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                listOf(L10n.text("下一餐吃什么") to L10n.text("我下一餐可以怎么搭配？"), L10n.text("蛋白质怎么补") to L10n.text("有哪些方便吃到的蛋白质食物？"), L10n.text("外卖怎么选") to L10n.text("帮我选一份有主食、蔬菜和蛋白质的外卖。"), L10n.text("看看这几天") to L10n.text("结合我分享的食记，给我两三条实用建议。")).chunked(2).forEachIndexed { rowIndex, row ->
                    Row(Modifier.padding(vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                        row.forEachIndexed { col, (title, prompt) ->
                            Box(Modifier.weight(1f).rotate(if ((rowIndex + col) % 2 == 0) -2f else 2f).clip(RoundedCornerShape(3.dp)).background(if ((rowIndex + col) % 2 == 0) Color(0xFFF5F0E5) else Color(0xFFE9EEF5)).clickable { vm.chatInput = prompt }.heightIn(min = 116.dp).padding(18.dp)) {
                                Box(Modifier.size(9.dp).align(Alignment.TopCenter).background(Color(0xFF262A30), CircleShape))
                                Text(title, Modifier.align(Alignment.Center).padding(top = 18.dp), color = Color(0xFF242424), fontSize = 19.sp, fontWeight = FontWeight.Medium)
                            }
                        }
                    }
                }
            }
            vm.diary.messages.forEach { message ->
                Column(Modifier.fillMaxWidth(), horizontalAlignment = if (message.role == "user") Alignment.End else Alignment.Start) {
                    Text(if (message.role == "user") L10n.text("你") else "kaii", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(6.dp))
                    Surface(shape = RoundedCornerShape(18.dp), color = if (message.role == "user") MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface) {
                        SelectionContainer {
                            if (message.role == "user") Text(message.content, Modifier.padding(16.dp), fontSize = 17.sp, lineHeight = 27.sp)
                            else Text(remember(message.content) { chatText(message.content) }, Modifier.padding(16.dp), fontSize = 17.sp, lineHeight = 27.sp)
                        }
                    }
                }
            }
            if (vm.chatBusy) { Text(L10n.text("正在想…"), color = MaterialTheme.colorScheme.primary); LinearProgressIndicator(Modifier.fillMaxWidth()) }
        }
        Surface(shadowElevation = 3.dp) {
            Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(shareRecords, { shareRecords = it }, enabled = !vm.chatBusy); Text(L10n.text("附上最近 7 天食记"), fontSize = 14.sp) }
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(vm.chatInput, { vm.chatInput = it.take(12_000) }, Modifier.weight(1f), placeholder = { Text(L10n.text("想问什么？")) }, maxLines = 5, shape = RoundedCornerShape(18.dp))
                    FilledIconButton(onClick = { if (vm.chatBusy) vm.stopChat() else confirmSend = true }, enabled = vm.chatBusy || (vm.chatInput.isNotBlank() && vm.ready), modifier = Modifier.size(52.dp)) {
                        Icon(if (vm.chatBusy) Icons.Outlined.Stop else Icons.AutoMirrored.Outlined.Send, if (vm.chatBusy) L10n.text("停止") else L10n.text("发送"))
                    }
                }
            }
        }
    }
    if (confirmSend) AlertDialog(onDismissRequest = { confirmSend = false }, title = { Text(L10n.text("发送给 {0}？", providers[vm.diary.settings.provider])) }, text = { Text(if (shareRecords) L10n.text("本次会分享对话和最近 7 天的食记。") else L10n.text("本次只分享当前对话。")) }, confirmButton = { TextButton(onClick = { confirmSend = false; vm.sendChat(shareRecords) }) { Text(L10n.text("发送")) } }, dismissButton = { TextButton(onClick = { confirmSend = false }) { Text(L10n.text("取消")) } })
    if (confirmClear) AlertDialog(onDismissRequest = { confirmClear = false }, title = { Text(L10n.text("清空这段对话？")) }, confirmButton = { TextButton(onClick = { vm.clearChat(); confirmClear = false }) { Text(L10n.text("清空")) } }, dismissButton = { TextButton(onClick = { confirmClear = false }) { Text(L10n.text("取消")) } })
}

private fun copyText(context: Context, text: String) {
    (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText(L10n.text("kaii 食记"), text))
}
private fun shareText(context: Context, text: String) {
    context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text) }, L10n.text("分享食记")))
}
@Composable private fun ExportScreen(vm: FoodViewModel) {
    val context = LocalContext.current
    var startText by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    var endText by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    val start = LocalDate.parse(startText); val end = LocalDate.parse(endText)
    val markdown = remember(vm.diary.meals, start, end, L10n.language) { exportMarkdown(vm.diary.meals, start, end) { L10n.text(it) } }
    val selected = vm.diary.meals.filter { !it.date.isBefore(start) && !it.date.isAfter(end) }.sortedWith(compareBy({ it.date }, { it.kind.ordinal }))
    var pendingText by rememberSaveable { mutableStateOf("") }
    val save = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/markdown")) { uri ->
        if (uri != null) try { context.contentResolver.openOutputStream(uri)?.bufferedWriter()?.use { it.write(pendingText) } ?: error(L10n.text("未能打开文件")); vm.status = L10n.text("文件已保存") } catch (_: Exception) { vm.error = L10n.text("保存失败，请重试") }
    }
    PageColumn {
        Heading(L10n.text("导出食记"), L10n.text("一键导出，交给你常用的 AI 看看饮食搭配。"))
        AssetImage("ExportScene", Modifier.fillMaxWidth().height(155.dp).clip(Round))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FilterChip(start == LocalDate.now() && end == LocalDate.now(), { startText = LocalDate.now().toString(); endText = startText }, label = { Text(L10n.text("今天")) })
            FilterChip(start == LocalDate.now().minusDays(6) && end == LocalDate.now(), { startText = LocalDate.now().minusDays(6).toString(); endText = LocalDate.now().toString() }, label = { Text(L10n.text("最近 7 天")) })
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            TextButton(onClick = { showDate(context, start) { startText = it.toString(); if (it.isAfter(end)) endText = it.toString() } }, Modifier.weight(1f)) { Text(start.format(DateTimeFormatter.ofPattern(L10n.text("M月d日"), L10n.locale)), fontSize = 18.sp); Icon(Icons.Outlined.ExpandMore, L10n.text("开始日期")) }
            Text("—", color = MaterialTheme.colorScheme.onSurfaceVariant)
            TextButton(onClick = { showDate(context, end) { endText = it.toString(); if (it.isBefore(start)) startText = it.toString() } }, Modifier.weight(1f)) { Text(end.format(DateTimeFormatter.ofPattern(L10n.text("M月d日"), L10n.locale)), fontSize = 18.sp); Icon(Icons.Outlined.ExpandMore, L10n.text("结束日期")) }
        }
        Surface(shape = RoundedCornerShape(6.dp), shadowElevation = 1.dp) {
            Column(Modifier.fillMaxWidth().padding(22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(L10n.text("kaii 食记"), fontFamily = FontFamily.Serif, fontSize = 26.sp, fontWeight = FontWeight.SemiBold)
                Text("$start — $end", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                HorizontalDivider(thickness = 2.dp, color = Blue)
                if (selected.isEmpty()) Text(L10n.text("未记录"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                selected.groupBy { it.date }.forEach { (day, meals) ->
                    Text(day.format(DateTimeFormatter.ofPattern(L10n.text("M月d日"), L10n.locale)), fontWeight = FontWeight.SemiBold)
                    meals.forEach { meal ->
                        Text(meal.kind.title, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Medium)
                        meal.items.forEach { food ->
                            Row(Modifier.fillMaxWidth()) { Text(food.name, Modifier.weight(1f), fontSize = 16.sp); Text("${food.grams.pretty()} ${food.unit}", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                        }
                        Text(L10n.text("{0} kcal · 蛋白质 {1} g", meal.total.kcal.pretty(), meal.total.protein.pretty()), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (meal.note.isNotBlank()) Text(meal.note, fontSize = 13.sp)
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                }
            }
        }
        PrimaryButton(L10n.text("复制食记"), Modifier.fillMaxWidth(), vm.ready) { copyText(context, markdown); vm.status = L10n.text("食记已复制") }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            TextButton(onClick = { try { shareText(context, markdown) } catch (_: Exception) { vm.error = L10n.text("暂时无法分享，可以先复制食记。") } }) { Icon(Icons.Outlined.IosShare, null); Text(L10n.text("  分享")) }
            TextButton(onClick = { pendingText = markdown; save.launch("kaii-$start-$end.md") }) { Icon(Icons.Outlined.SaveAlt, null); Text(L10n.text("  保存文件")) }
        }
    }
}

@Composable private fun SettingsScreen(vm: FoodViewModel) {
    val context = LocalContext.current
    var settings by remember(vm.diary.settings) { mutableStateOf(vm.diary.settings) }
    var goal by remember(vm.diary.settings.proteinGoal) { mutableStateOf(vm.diary.settings.proteinGoal.takeIf { it > 0 }?.pretty() ?: "") }
    var glmKey by remember { mutableStateOf("") }; var dsKey by remember { mutableStateOf("") }; var kimiKey by remember { mutableStateOf("") }
    var removeProvider by remember { mutableStateOf<String?>(null) }
    var backupPending by remember { mutableStateOf("") }
    var importUri by remember { mutableStateOf<Uri?>(null) }
    val backup = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) try { context.contentResolver.openOutputStream(uri)?.bufferedWriter()?.use { it.write(backupPending) } ?: error(L10n.text("未能打开文件")); vm.status = L10n.text("备份已保存") } catch (_: Exception) { vm.error = L10n.text("备份保存失败，请重试") }
    }
    val restore = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> importUri = uri }
    PageColumn {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Image(painterResource(R.drawable.brand_icon), L10n.text("kaii 图标"), Modifier.size(72.dp).clip(RoundedCornerShape(20.dp)))
            Column { Text(L10n.text("kaii 食记"), fontSize = 28.sp, fontFamily = FontFamily.Serif); Text("v${BuildConfig.VERSION_NAME}", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        TextButton(onClick = vm::showWelcome) { Text(L10n.text("使用说明与 AI 设置")) }
        LanguagePicker()
        SettingsSection(L10n.text("个人目标")) {
            NumberField(L10n.text("每日蛋白质 · g（留空关闭）"), goal, { goal = it })
            Text(L10n.text("这是你自己设置的参考值，可以随时关闭。"), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        SettingsSection(L10n.text("AI 模型")) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) { providers.forEach { (id, title) -> FilterChip(settings.provider == id, { settings = settings.copy(provider = id) }, label = { Text(title) }) } }
            OutlinedTextField(settings.glmModel, { settings = settings.copy(glmModel = it) }, Modifier.fillMaxWidth(), label = { Text(L10n.text("GLM 对话模型")) }, singleLine = true)
            OutlinedTextField(settings.visionModel, { settings = settings.copy(visionModel = it) }, Modifier.fillMaxWidth(), label = { Text(L10n.text("GLM 照片识别模型")) }, singleLine = true)
            OutlinedTextField(settings.deepseekModel, { settings = settings.copy(deepseekModel = it) }, Modifier.fillMaxWidth(), label = { Text(L10n.text("DeepSeek 对话模型")) }, singleLine = true)
            OutlinedTextField(settings.kimiModel, { settings = settings.copy(kimiModel = it) }, Modifier.fillMaxWidth(), label = { Text(L10n.text("Kimi 模型")) }, singleLine = true)
            Text(L10n.text("记餐与对话使用所选服务。GLM 会按图文切换模型。"), fontSize = 13.sp)
            PrimaryButton(L10n.text("保存设置"), Modifier.fillMaxWidth(), vm.ready) {
                val value = if (goal.isBlank()) 0.0 else goal.toDoubleOrNull()
                if (value == null) vm.error = L10n.text("请检查蛋白质目标") else vm.saveSettings(settings.copy(proteinGoal = value))
            }
        }
        SettingsSection(L10n.text("模型账户")) {
            Text(L10n.text("GLM：{0}　DeepSeek：{1}", if (vm.glmReady) L10n.text("已配置") else L10n.text("未配置"), if (vm.deepseekReady) L10n.text("已配置") else L10n.text("未配置")), color = MaterialTheme.colorScheme.primary)
            Text(L10n.text("填入你自己的 Key，选一家即可。调用费用由你的 AI 账户支付。"), fontSize = 14.sp)
            OutlinedTextField(glmKey, { glmKey = it }, Modifier.fillMaxWidth(), label = { Text(L10n.text("替换 GLM Key")) }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
            Row { TextButton(onClick = { vm.saveKey("glm", glmKey); glmKey = "" }, enabled = glmKey.isNotBlank()) { Text(L10n.text("保存 GLM")) }; Spacer(Modifier.weight(1f)); TextButton(onClick = { removeProvider = "glm" }, enabled = vm.glmReady) { Text(L10n.text("移除")) } }
            OutlinedTextField(dsKey, { dsKey = it }, Modifier.fillMaxWidth(), label = { Text(L10n.text("替换 DeepSeek Key")) }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
            Row { TextButton(onClick = { vm.saveKey("deepseek", dsKey); dsKey = "" }, enabled = dsKey.isNotBlank()) { Text(L10n.text("保存 DeepSeek")) }; Spacer(Modifier.weight(1f)); TextButton(onClick = { removeProvider = "deepseek" }, enabled = vm.deepseekReady) { Text(L10n.text("移除")) } }
            Text(L10n.text("Kimi · {0}", if (vm.kimiReady) L10n.text("已配置") else L10n.text("未配置")), color = MaterialTheme.colorScheme.primary)
            OutlinedTextField(kimiKey, { kimiKey = it }, Modifier.fillMaxWidth(), label = { Text("Kimi Key") }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
            Row { TextButton(onClick = { vm.saveKey("kimi", kimiKey); kimiKey = "" }, enabled = kimiKey.isNotBlank()) { Text(L10n.text("保存 Kimi")) }; Spacer(Modifier.weight(1f)); TextButton(onClick = { removeProvider = "kimi" }, enabled = vm.kimiReady) { Text(L10n.text("移除")) } }
        }
        SettingsSection(L10n.text("备份与更新")) {
            Text(L10n.text("收到新版 APK 后直接打开，选择更新即可。请保留旧 App，不用先卸载。"))
            Text(L10n.text("新版安装包可在 GitHub Releases 下载。"), fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedButton(onClick = { backupPending = vm.diary.json().toString(2); backup.launch("kaii-backup-${LocalDate.now()}.json") }, Modifier.fillMaxWidth().heightIn(min = 50.dp), enabled = vm.ready) { Text(L10n.text("备份食记")) }
            OutlinedButton(onClick = { restore.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }, Modifier.fillMaxWidth().heightIn(min = 50.dp), enabled = vm.ready) { Text(L10n.text("导入食记备份")) }
            Text(L10n.text("备份包含食记、常用食物、设置和对话。导入会合并食记与常用食物，保留当前设置和对话。照片与 Key 留在本机。"), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        SettingsSection(L10n.text("数据与隐私")) {
            Text(L10n.text("食记、照片和对话保存在本机。手动记录和标签文字识别可离线使用。"))
            Text(L10n.text("使用 AI 时，确认后发送所选内容给 GLM、DeepSeek 或 Kimi。照片会移除原始拍摄位置等元数据。"))
            Text(L10n.text("本版没有广告。卸载会移除本机数据，请先备份。"), fontSize = 14.sp)
            TextButton(onClick = vm::reload) { Text(L10n.text("重新读取食记")) }
        }
    }
    removeProvider?.let { provider -> AlertDialog(onDismissRequest = { removeProvider = null }, title = { Text(L10n.text("移除 {0} Key？", provider)) }, text = { Text(L10n.text("之后需要重新填写才能调用这个服务。")) }, confirmButton = { TextButton(onClick = { vm.removeKey(provider); removeProvider = null }) { Text(L10n.text("移除")) } }, dismissButton = { TextButton(onClick = { removeProvider = null }) { Text(L10n.text("取消")) } }) }
    importUri?.let { uri -> AlertDialog(onDismissRequest = { importUri = null }, title = { Text(L10n.text("导入这份食记？")) }, text = { Text(L10n.text("会保留现有记录，合并备份中的食记。")) }, confirmButton = { TextButton(onClick = { vm.importBackup(uri); importUri = null }) { Text(L10n.text("导入")) } }, dismissButton = { TextButton(onClick = { importUri = null }) { Text(L10n.text("取消")) } }) }
}
@Composable private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, fontSize = 21.sp, fontWeight = FontWeight.SemiBold)
        Surface(shape = Round) { Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp), content = content) }
    }
}
