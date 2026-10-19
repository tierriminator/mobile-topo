import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads android/key.properties locally and environment
// variables on CI; see "Releasing" in README.md.
val keyProperties = Properties().apply {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}

fun signingValue(property: String, environmentVariable: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(environmentVariable)

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")

android {
    namespace = "ch.tierry.mobiletopo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Never change this: Android treats an app with another ID as a
        // different app, so existing installs would not get updates.
        applicationId = "ch.tierry.mobiletopo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Updates must be signed with the same key as the installed app, so a
// release build without the release key fails instead of falling back.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        if (releaseStoreFile == null) {
            throw GradleException(
                "No release signing key: create android/key.properties " +
                    "or set ANDROID_KEYSTORE_PATH (see \"Releasing\" in README.md)",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
