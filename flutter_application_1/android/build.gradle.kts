buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.0")
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    layout.buildDirectory.set(rootProject.rootDir.parentFile.resolve("build/${project.name}"))
}

subprojects {
    if (name != "app") {
        beforeEvaluate {
            extensions.extraProperties["flutter"] = mapOf(
                "compileSdkVersion" to 36,
                "minSdkVersion"     to 26,
                "targetSdkVersion"  to 36,
                "ndkVersion"        to "28.2.13676358"
            )
        }
    }
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
                apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.rootDir.parentFile.resolve("build"))
}
