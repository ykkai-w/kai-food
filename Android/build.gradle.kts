plugins {
    id("com.android.application") version "8.9.2" apply false
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.20" apply false
}

allprojects {
    providers.gradleProperty("kaiiBuildRoot").orNull?.let { root ->
        layout.buildDirectory.set(file("$root/${project.name}"))
    }
}
