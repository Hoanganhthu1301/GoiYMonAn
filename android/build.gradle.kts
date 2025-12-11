    buildscript {
        repositories {
            google()
            mavenCentral()
        }
        dependencies {
            classpath("com.android.tools.build:gradle:8.1.2")
            classpath("com.google.gms:google-services:4.4.2") // ✅ dòng bắt buộc để Firebase chạy
        }
    }

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
    project.configurations.all {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}


    tasks.register<Delete>("clean") {
        delete(rootProject.layout.buildDirectory)
    }
