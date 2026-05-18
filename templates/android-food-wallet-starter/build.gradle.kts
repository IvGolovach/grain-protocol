plugins {
    kotlin("jvm") version "1.8.22"
}

group = "dev.grain.templates"
version = "0.1.0"

val externalBuildDir = providers.systemProperty("grain.kotlin.buildDir")
if (externalBuildDir.isPresent) {
    layout.buildDirectory.set(file(externalBuildDir.get()))
}

sourceSets {
    main {
        kotlin.srcDir("../../sdk/kotlin/src/main/kotlin")
    }
}

dependencies {
    implementation("net.java.dev.jna:jna:5.14.0")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin:2.17.2")
    testImplementation(kotlin("stdlib"))
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "11"
        freeCompilerArgs += "-Xjsr305=strict"
    }
}

tasks.register<JavaExec>("runAndroidFoodWalletStarterSmoke") {
    group = LifecycleBasePlugin.VERIFICATION_GROUP
    description = "Run the Android Food Wallet starter through estimate, draft, confirm, and safe summary."
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("dev.grain.templates.androidfoodwallet.AndroidFoodWalletStarterSmokeKt")
    dependsOn("testClasses")
}

tasks.named("check") {
    dependsOn("runAndroidFoodWalletStarterSmoke")
}
