plugins {
    kotlin("jvm") version "1.8.22"
}

group = "dev.grain.examples"
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

val repoRoot = rootProject.layout.projectDirectory.dir("../..").asFile.canonicalFile
val osName = System.getProperty("os.name").toLowerCase()
val nativeLibraryName = when {
    osName.contains("mac") -> "libgrain_client_core.dylib"
    osName.contains("linux") -> "libgrain_client_core.so"
    osName.contains("windows") -> "grain_client_core.dll"
    else -> error("Unsupported host OS for Grain scanner example")
}
val rustDebugLibrary = repoRoot.resolve("core/rust/target/debug/$nativeLibraryName")

tasks.withType<Test>().configureEach {
    systemProperty("grain.repoRoot", repoRoot.path)
    systemProperty("uniffi.component.grain_client_core.libraryOverride", rustDebugLibrary.path)
}

tasks.register<JavaExec>("runScannerShellSmoke") {
    group = LifecycleBasePlugin.VERIFICATION_GROUP
    description = "Run the reference scanner shell through the public Kotlin GrainClient API."
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("dev.grain.examples.androidscanner.ScannerShellTestKt")
    systemProperty("grain.repoRoot", repoRoot.path)
    systemProperty("uniffi.component.grain_client_core.libraryOverride", rustDebugLibrary.path)
    dependsOn("testClasses")
}

tasks.register("runAndroidParitySmoke") {
    group = LifecycleBasePlugin.VERIFICATION_GROUP
    description = "Run the Android scanner parity smoke through the public Kotlin GrainClient API."
    dependsOn("runScannerShellSmoke")
}

tasks.named("check") {
    dependsOn("runScannerShellSmoke")
}
