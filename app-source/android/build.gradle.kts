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
    project.plugins.withId("com.android.library") {
        val androidExt = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
        if (androidExt.namespace == null) {
            androidExt.namespace = "com.example.${project.name.replace('-', '_')}"
        }
    }
    plugins.withType<org.jetbrains.kotlin.gradle.plugin.KotlinBasePluginWrapper> {
        val kotlinExt = project.extensions.getByName("kotlin") as org.jetbrains.kotlin.gradle.dsl.KotlinSingleTargetExtension<*>
        kotlinExt.jvmToolchain(21)
    }
}

subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
        androidExt?.compileSdkVersion(36)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
