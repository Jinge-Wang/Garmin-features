import com.android.build.api.artifact.SingleArtifact

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "app.cardloader"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "app.cardloader"
        minSdk = 30
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all { test ->
                test.maxHeapSize = "2g"
                // Android Studio's JDK keeps the internals Robolectric reaches for closed unless they are opened.
                test.jvmArgs(
                    "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED",
                    "--add-opens=java.base/java.io=ALL-UNNAMED",
                    "--add-opens=java.base/java.lang=ALL-UNNAMED",
                )
                test.systemProperty("robolectric.logging.enabled", "false")
                test.systemProperty("cardloader.fixtures", rootProject.layout.projectDirectory.dir("fixtures").asFile.absolutePath)
                test.testLogging {
                    events("failed")
                    exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
                }
            }
        }
    }
}

// The guarantee of this app: it never asks for network access. This task reads the merged debug
// manifest (the app's own plus every library's) and fails the build if INTERNET is in it.
abstract class VerifyNoInternet : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val manifest: RegularFileProperty

    @TaskAction
    fun verify() {
        val text = manifest.get().asFile.readText()
        val names = Regex("""<uses-permission[a-z0-9-]*\s[^>]*?android:name="([^"]+)"""")
            .findAll(text).map { it.groupValues[1] }.toList().sorted()
        println("Permissions in the merged debug manifest: " + (if (names.isEmpty()) "none" else names.joinToString(", ")))
        val network = names.filter { it == "android.permission.INTERNET" }
        if (network.isNotEmpty()) {
            throw GradleException("The merged manifest requests ${network.joinToString()}; this app must not.")
        }
    }
}

val verifyNoInternet = tasks.register<VerifyNoInternet>("verifyNoInternet")

androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        verifyNoInternet.configure {
            manifest.set(variant.artifacts.get(SingleArtifact.MERGED_MANIFEST))
        }
    }
}

tasks.configureEach {
    if (name == "assembleDebug" || name == "check") dependsOn(verifyNoInternet)
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.zxing.core)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.connectiq.sdk)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.serialization.json)
    testImplementation(libs.robolectric)
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.androidx.compose.ui.test.junit4)
    testImplementation(libs.androidx.test.espresso.core)
}
