import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val signingFile = providers.gradleProperty("kaiiSigningFile").orNull?.let { file(it) }
val signing = Properties().apply { if (signingFile?.exists() == true) signingFile.inputStream().use { load(it) } }
val isPrivateBuild = providers.gradleProperty("privateBuild").orNull == "true"
// Separate directories prevent a later public build from inheriting a private asset.
val generatedPrivateAssets = layout.buildDirectory.dir(if (isPrivateBuild) "generated/privateAssets" else "generated/publicAssets")
val preparePrivateAssets by tasks.registering(Sync::class) {
    into(generatedPrivateAssets)
    if (isPrivateBuild) {
        from(rootProject.file("../App/PrivateProviders.json"))
        doFirst { check(rootProject.file("../App/PrivateProviders.json").isFile) { "Private provider configuration is missing." } }
    }
}

android {
    namespace = "cn.kaii.food"
    compileSdk = 35
    defaultConfig {
        applicationId = "cn.kaii.food.android"
        minSdk = 28
        targetSdk = 35
        versionCode = 4
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs {
        if (signing.isNotEmpty()) create("family") {
            storeFile = file(signing.getProperty("storeFile"))
            storePassword = signing.getProperty("storePassword")
            keyAlias = signing.getProperty("keyAlias")
            keyPassword = signing.getProperty("keyPassword")
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            if (signing.isNotEmpty()) signingConfig = signingConfigs.getByName("family")
        }
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    sourceSets["main"].assets.srcDir(generatedPrivateAssets)
    packaging { resources.excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1") }
    testOptions { unitTests.isReturnDefaultValues = true }
}
tasks.named("preBuild").configure { dependsOn(preparePrivateAssets) }

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.04.01")
    implementation(composeBom)
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.1")
    // Bundled Chinese OCR model: works offline, does not require Google Play Services.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    androidTestImplementation(composeBom)
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
