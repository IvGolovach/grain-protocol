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
        kotlin.srcDir("../android-scanner/src/main/kotlin")
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
    else -> error("Unsupported host OS for Grain Android reference app")
}
val rustDebugLibrary = repoRoot.resolve("core/rust/target/debug/$nativeLibraryName")
val rustDebugLibraryOverride = providers
    .systemProperty("grain.kotlin.rustDebugLibrary")
    .map { file(it) }
    .orElse(rustDebugLibrary)

tasks.withType<Test>().configureEach {
    systemProperty("grain.repoRoot", repoRoot.path)
    systemProperty("uniffi.component.grain_client_core.libraryOverride", rustDebugLibraryOverride.get().path)
}

tasks.register<JavaExec>("runAndroidReferenceAppSmoke") {
    group = LifecycleBasePlugin.VERIFICATION_GROUP
    description = "Run the Android reference app workflow through public SDK/example modules."
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("dev.grain.examples.androidreferenceapp.GrainAndroidReferenceAppSmokeKt")
    systemProperty("grain.repoRoot", repoRoot.path)
    systemProperty("uniffi.component.grain_client_core.libraryOverride", rustDebugLibraryOverride.get().path)
    dependsOn("testClasses")
}

tasks.named("check") {
    dependsOn("runAndroidReferenceAppSmoke")
}
