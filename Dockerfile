FROM ghcr.io/cirruslabs/android-sdk:36

ENV ANDROID_HOME=/opt/android-sdk-linux \
    ANDROID_SDK_ROOT=/opt/android-sdk-linux \
    GRADLE_USER_HOME=/root/.gradle \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl unzip zip cmake ninja-build && \
    rm -rf /var/lib/apt/lists/*

RUN yes | sdkmanager --licenses > /dev/null 2>&1 || true && \
    sdkmanager \
      "platform-tools" \
      "platforms;android-35" \
      "platforms;android-36.1" \
      "build-tools;36.0.0" \
      "cmake;3.22.1" \
      "ndk;28.2.13676358"

RUN curl -fsSL https://services.gradle.org/distributions/gradle-9.3.1-bin.zip -o /tmp/g.zip && \
    unzip -q /tmp/g.zip -d /opt && \
    rm /tmp/g.zip

ENV PATH="/opt/gradle-9.3.1/bin:${PATH}"
