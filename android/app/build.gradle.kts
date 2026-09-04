import java.io.FileInputStream
import java.util.Properties

val environment = Properties().apply {
    val environmentFile = rootProject.file("../.env")
    if (environmentFile.exists()) {
        FileInputStream(environmentFile).use(::load)
    }
}

// Release builds must use a private upload key. Keep this file local; it is
// intentionally loaded from android/key.properties and never from source.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

val isReleaseBuild = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}
if (isReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "Missing android/key.properties. Configure the upload keystore before building a release."
    )
}

fun requiredKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException("Missing '$name' in android/key.properties")

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "mn.carcare.carcare_customer_mobile"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "mn.infosystems.mn.customer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAP_API_KEY"] =
            environment.getProperty("GOOGLE_MAP_API_KEY", "")
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                keyAlias = requiredKeystoreProperty("keyAlias")
                keyPassword = requiredKeystoreProperty("keyPassword")
                storeFile = file(requiredKeystoreProperty("storeFile"))
                storePassword = requiredKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
