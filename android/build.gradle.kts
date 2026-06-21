import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library") 
    id("org.jetbrains.kotlin.android") version "2.3.21"
}

group = "com.jhomlala.catcher"
version = "1.0-SNAPSHOT"

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

android {
    namespace = "com.jhomlala.catcher"
    compileSdk = 37

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/main/kotlin")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_21)
    }
}
