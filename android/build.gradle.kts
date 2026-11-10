allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

fun configureProject(p: Project) {
    val android = p.extensions.findByName("android") ?: return
    try {
        val getNamespace = android.javaClass.getMethod("getNamespace")
        val ns = getNamespace.invoke(android)
        if (ns == null) {
            val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
            val targetNamespace = if (p.name.contains("on_audio_query")) {
                "com.lucasjosino.on_audio_query"
            } else if (p.name.contains("ringtone_set")) {
                "acr.rt.ringtone_set_plus"
            } else {
                "com.soniq.plugin.${p.name.replace("-", "_")}"
            }
            setNamespace.invoke(android, targetNamespace)
        }
    } catch (_: Exception) {}

    try {
        val setCompileSdkVersion = android.javaClass.getMethod("compileSdkVersion", String::class.java)
        setCompileSdkVersion.invoke(android, "android-36")
    } catch (_: Exception) {
        try {
            val setCompileSdkVersionInt = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
            setCompileSdkVersionInt.invoke(android, 36)
        } catch (_: Exception) {}
    }
}

subprojects {
    val p = this
    if (p.name != "app") {
        if (p.state.executed) {
            configureProject(p)
        } else {
            p.afterEvaluate {
                configureProject(p)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
