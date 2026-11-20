FROM ghcr.io/cirruslabs/android-sdk:36

ENV GRADLE_USER_HOME=/root/.gradle

# Install curl, unzip, and Node.js 22 (for React Native, Expo, and Capacitor builds)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl unzip ca-certificates gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Gradle 8.11.1 binary globally (so projects missing ./gradlew still build)
RUN curl -fsSL https://services.gradle.org/distributions/gradle-8.11.1-bin.zip -o /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt && \
    rm /tmp/gradle.zip
ENV PATH="/opt/gradle-8.11.1/bin:${PATH}"

# Pre-warm AndroidX & Jetpack Compose dependencies
WORKDIR /warmup
RUN printf 'android.useAndroidX=true\norg.gradle.jvmargs=-Xmx3g\n' > gradle.properties && \
    printf 'plugins {\n  id("com.android.application") version "8.9.1" apply false\n  id("org.jetbrains.kotlin.android") version "2.1.10" apply false\n  id("org.jetbrains.kotlin.plugin.compose") version "2.1.10" apply false\n}\n' > build.gradle.kts && \
    printf 'pluginManagement {\n  repositories { google(); mavenCentral(); gradlePluginPortal() }\n}\ndependencyResolutionManagement {\n  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)\n  repositories { google(); mavenCentral() }\n}\ninclude(":app")\n' > settings.gradle.kts && \
    mkdir -p app/src/main && \
    printf 'plugins {\n  id("com.android.application")\n  id("org.jetbrains.kotlin.android")\n  id("org.jetbrains.kotlin.plugin.compose")\n}\nandroid {\n  namespace = "com.shipsign.warmup"\n  compileSdk = 36\n  defaultConfig { applicationId = "com.shipsign.warmup"; minSdk = 26; targetSdk = 36 }\n  compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }\n  kotlinOptions { jvmTarget = "17" }\n}\ndependencies {\n  implementation("androidx.core:core-ktx:1.15.0")\n  implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")\n  implementation("androidx.activity:activity-compose:1.10.1")\n  implementation(platform("androidx.compose:compose-bom:2025.02.00"))\n  implementation("androidx.compose.ui:ui")\n  implementation("androidx.compose.material3:material3")\n}\n' > app/build.gradle.kts && \
    printf '<manifest/>\n' > app/src/main/AndroidManifest.xml && \
    gradle wrapper --gradle-version 8.11.1 --no-daemon && \
    ./gradlew assembleRelease --no-daemon && \
    rm -rf /warmup
