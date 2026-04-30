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
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val namespace = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (namespace == null) {
                    val groupName = project.group.toString()
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, groupName)
                }
            } catch (e: Exception) {
                // Silencioso
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}