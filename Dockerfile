FROM ghcr.io/cirruslabs/android-sdk:36

ENV ANDROID_HOME=/opt/android-sdk-linux \
    ANDROID_SDK_ROOT=/opt/android-sdk-linux \
    GRADLE_USER_HOME=/root/.gradle \
    FLUTTER_ROOT=/opt/flutter \
    DEBIAN_FRONTEND=noninteractive

# 1. Core Linux build tools, Node.js 22 (RN/Expo/Capacitor), CMake/Ninja (NDK), Python & jq
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl wget unzip zip git ca-certificates gnupg \
      cmake ninja-build jq python3 xz-utils libglu1-mesa && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# 2. Pre-install Android SDK Platforms (34, 35, 36, 36.1), Build-Tools, CMake & NDKs (r27 + r28)
RUN yes | sdkmanager --licenses > /dev/null 2>&1 || true && \
    sdkmanager \
      "platform-tools" \
      "platforms;android-34" \
      "platforms;android-35" \
      "platforms;android-36" \
      "platforms;android-36.1" \
      "build-tools;34.0.0" \
      "build-tools;35.0.0" \
      "build-tools;36.0.0" \
      "cmake;3.22.1" \
      "ndk;27.2.12479018" \
      "ndk;28.2.13676358"

# 3. Install Gradle 9.3.1 (default) and Gradle 8.11.1 (AGP 8.x fallback)
RUN curl -fsSL https://services.gradle.org/distributions/gradle-9.3.1-bin.zip -o /tmp/gradle9.zip && \
    unzip -q /tmp/gradle9.zip -d /opt && \
    rm /tmp/gradle9.zip && \
    curl -fsSL https://services.gradle.org/distributions/gradle-8.11.1-bin.zip -o /tmp/gradle8.zip && \
    unzip -q /tmp/gradle8.zip -d /opt && \
    rm /tmp/gradle8.zip && \
    ln -sf /opt/gradle-9.3.1/bin/gradle /usr/local/bin/gradle && \
    ln -sf /opt/gradle-8.11.1/bin/gradle /usr/local/bin/gradle8

# 4. Install Flutter Stable SDK + Android precache
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter && \
    /opt/flutter/bin/flutter config --no-analytics --android-sdk /opt/android-sdk-linux && \
    /opt/flutter/bin/flutter precache --android && \
    yes | /opt/flutter/bin/flutter doctor --android-licenses > /dev/null 2>&1 || true
ENV PATH="/opt/flutter/bin:/opt/gradle-9.3.1/bin:${PATH}"

# 5. Install Godot 4.3-stable Linux Headless + Official Android Export Templates
RUN curl -fsSL https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip -o /tmp/godot.zip && \
    unzip -q /tmp/godot.zip -d /opt/godot && \
    mv /opt/godot/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm -rf /tmp/godot.zip /opt/godot && \
    curl -fsSL https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz -o /tmp/godot_tpl.tpz && \
    unzip -q /tmp/godot_tpl.tpz -d /tmp/godot_tpl && \
    mkdir -p /root/.local/share/godot/export_templates && \
    mv /tmp/godot_tpl/templates /root/.local/share/godot/export_templates/4.3.stable && \
    rm -rf /tmp/godot_tpl.tpz /tmp/godot_tpl

# 6. Pre-warm Maven caches for BOTH AGP 9.1.1 (Gradle 9.3.1) and AGP 8.9.1 (Gradle 8.11.1)
WORKDIR /warmup_agp9
RUN printf 'android.useAndroidX=true\norg.gradle.jvmargs=-Xmx3g\n' > gradle.properties && \
    printf 'plugins {\n  id("com.android.application") version "9.1.1" apply false\n  id("org.jetbrains.kotlin.plugin.compose") version "2.2.10" apply false\n}\n' > build.gradle.kts && \
    printf 'pluginManagement {\n  repositories { google(); mavenCentral(); gradlePluginPortal() }\n}\ndependencyResolutionManagement {\n  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)\n  repositories { google(); mavenCentral() }\n}\ninclude(":app")\n' > settings.gradle.kts && \
    mkdir -p app/src/main && \
    printf 'plugins {\n  id("com.android.application")\n  id("org.jetbrains.kotlin.plugin.compose")\n}\nandroid {\n  namespace = "com.shipsign.warmup9"\n  compileSdk = 36\n  defaultConfig { applicationId = "com.shipsign.warmup9"; minSdk = 26; targetSdk = 36 }\n  compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }\n}\ndependencies {\n  implementation("androidx.core:core-ktx:1.15.0")\n  implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")\n  implementation("androidx.activity:activity-compose:1.10.1")\n  implementation(platform("androidx.compose:compose-bom:2025.02.00"))\n  implementation("androidx.compose.ui:ui")\n  implementation("androidx.compose.material3:material3")\n}\n' > app/build.gradle.kts && \
    printf '<manifest/>\n' > app/src/main/AndroidManifest.xml && \
    gradle wrapper --gradle-version 9.3.1 --no-daemon && \
    ./gradlew assembleRelease --no-daemon && \
    rm -rf /warmup_agp9

WORKDIR /warmup_agp8
RUN printf 'android.useAndroidX=true\norg.gradle.jvmargs=-Xmx3g\n' > gradle.properties && \
    printf 'plugins {\n  id("com.android.application") version "8.9.1" apply false\n  id("org.jetbrains.kotlin.android") version "2.1.10" apply false\n}\n' > build.gradle.kts && \
    printf 'pluginManagement {\n  repositories { google(); mavenCentral(); gradlePluginPortal() }\n}\ndependencyResolutionManagement {\n  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)\n  repositories { google(); mavenCentral() }\n}\ninclude(":app")\n' > settings.gradle.kts && \
    mkdir -p app/src/main && \
    printf 'plugins {\n  id("com.android.application")\n  id("org.jetbrains.kotlin.android")\n}\nandroid {\n  namespace = "com.shipsign.warmup8"\n  compileSdk = 35\n  defaultConfig { applicationId = "com.shipsign.warmup8"; minSdk = 24; targetSdk = 35 }\n  compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }\n  kotlinOptions { jvmTarget = "17" }\n}\ndependencies {\n  implementation("androidx.core:core-ktx:1.15.0")\n  implementation("androidx.appcompat:appcompat:1.7.0")\n}\n' > app/build.gradle.kts && \
    printf '<manifest/>\n' > app/src/main/AndroidManifest.xml && \
    gradle8 wrapper --gradle-version 8.11.1 --no-daemon && \
    ./gradlew assembleRelease --no-daemon && \
    rm -rf /warmup_agp8
