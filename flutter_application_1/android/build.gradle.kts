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
}

tasks.register<Delete>("clean") {
    delete(rootProject.rootDir.parentFile.resolve("build"))
}
