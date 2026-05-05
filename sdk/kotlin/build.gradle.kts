plugins {
    kotlin("jvm") version "1.8.22"
}

group = "dev.grain"
version = "0.1.0"

val externalBuildDir = providers.systemProperty("grain.kotlin.buildDir")
if (externalBuildDir.isPresent) {
    layout.buildDirectory.set(file(externalBuildDir.get()))
}

dependencies {
    implementation("net.java.dev.jna:jna:5.14.0")
    testImplementation(kotlin("stdlib"))
    testImplementation("com.fasterxml.jackson.module:jackson-module-kotlin:2.17.2")
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
    else -> error("Unsupported host OS for Grain Kotlin fixture runner")
}
val rustDebugLibrary = repoRoot.resolve("core/rust/target/debug/$nativeLibraryName")

tasks.register<JavaExec>("runFixtureRunner") {
    group = LifecycleBasePlugin.VERIFICATION_GROUP
    description = "Run shared client workflow fixtures through the public Kotlin GrainClient API."
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("dev.grain.fixture.GrainClientFixtureRunnerKt")
    systemProperty("grain.repoRoot", repoRoot.path)
    systemProperty("uniffi.component.grain_client_core.libraryOverride", rustDebugLibrary.path)
    dependsOn("testClasses")
}

tasks.register<JavaExec>("runAndroidAdaptersSmoke") {
    group = LifecycleBasePlugin.VERIFICATION_GROUP
    description = "Run Android adapter snapshot persistence smoke tests."
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("dev.grain.android.GrainAndroidAdaptersSmokeKt")
    dependsOn("testClasses")
}

tasks.named("check") {
    dependsOn("runFixtureRunner")
    dependsOn("runAndroidAdaptersSmoke")
}
