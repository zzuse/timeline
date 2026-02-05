# Flutter Android Timeline App - Setup Commands

## Flutter Installation (user ran these)
```bash
# Download Flutter SDK
mkdir -p ~/development && cd ~/development
curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.24.3-stable.zip

# Unzip Flutter
unzip flutter_macos_arm64_3.24.3-stable.zip

# Add Flutter to PATH
export PATH="$HOME/development/flutter/bin:$PATH"

# Verify Flutter works
flutter --version

# Create the project
cd timelineAndroid
flutter create --org com.zzuse --project-name timeline --platforms android .
```

## Development Commands
```bash
# Get dependencies
flutter pub get

# Run the app on connected device/emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Testing Commands
```bash
# Run all tests
flutter test

# Run tests with verbose output
flutter test --reporter expanded

# Run specific test file
flutter test test/models/note_test.dart

# Run tests matching a pattern
flutter test --name "Note.create"

# Run tests with coverage
flutter test --coverage

# View coverage report (requires lcov)
# brew install lcov
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Watch tests (re-run on file changes)
flutter test --watch
```

## Android Device Setup
```bash
# Navigate to your project
cd timelineAndroid

# Add Flutter to PATH
export PATH="$HOME/development/flutter/bin:$PATH"

# Check if your device is detected
flutter devices

# You should see your device listed here, if not, run flutter doctor
flutter doctor

# fix not found devices issue
brew install android-platform-tools

# Verify ADB sees your device
adb devices
```

# Java Setup
```bash
# Install OpenJDK via Homebrew
brew install openjdk@17

# Add Java to your PATH (for zsh)
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc

# Link it so the system can find it
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# Reload your shell
source ~/.zshrc

# Verify Java is installed
java -version
```

# Android SDK
```bash
# Install Android command-line tools via Homebrew
brew install --cask android-commandlinetools

# Set the correct Android SDK path
flutter config --android-sdk /opt/homebrew/share/android-commandlinetools

# Install the required SDK components
sdkmanager "platforms;android-35" "build-tools;33.0.1"

# Accept licenses again with the proper path
yes | sdkmanager --licenses

# found adb not install
flutter doctor -v

# relocate adb
sdkmanager "platform-tools"

```

# Run
```bash
# Then run Flutter again
cd timelineAndroid
flutter run
```

## Android Emulator Commands
```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Or use Android Studio's AVD Manager
```

## Sync Testing Commands

### Monitor Sync Activity
```bash
# Watch sync-related logs in real-time
adb logcat | grep -E "Notesync|SyncEngine|SyncQueue|AuthSession"

# Watch all Flutter output
adb logcat | grep -E "flutter|zzuse.timeline"

# Save logs to file
adb logcat | grep -E "Notesync|SyncEngine" > sync_debug.log
```

### Test Media Sync
```bash
# Trigger hot reload after code changes
# In the flutter run terminal, press 'r'

# Trigger hot restart (full app restart)
# In the flutter run terminal, press 'R'

# Clear app data to test fresh sync
adb shell pm clear com.zzuse.timeline

# Check sync queue directory on device
adb shell "run-as com.zzuse.timeline ls -la /data/data/com.zzuse.timeline/app_flutter/SyncQueue"

# Check media files on device
adb shell "run-as com.zzuse.timeline ls -la /data/data/com.zzuse.timeline/app_flutter/Images"
adb shell "run-as com.zzuse.timeline ls -la /data/data/com.zzuse.timeline/app_flutter/Audio"
```

### Network Debugging
```bash
# Enable airplane mode to test offline queue
adb shell cmd wifi set-wifi-enabled disabled
adb shell cmd connectivity airplane-mode enable

# Disable airplane mode
adb shell cmd wifi set-wifi-enabled enabled
adb shell cmd connectivity airplane-mode disable
```

## Build Commands

### Debug Builds
```bash
# Build debug APK
flutter build apk --debug

# Install debug APK on connected device
flutter install
```

### Release Builds
```bash
# Build release APK
flutter build apk --release

# The APK will be at:
# build/app/outputs/flutter-apk/app-release.apk

# Build App Bundle for Play Store
flutter build appbundle --release
```

## Useful Debugging

### Check Package Dependencies
```bash
# See all dependencies
flutter pub deps

# Update dependencies
flutter pub upgrade

# Get outdated packages
flutter pub outdated
```

### Performance Analysis
```bash
# Run with performance overlay
flutter run --profile

# Analyze app size
flutter build apk --analyze-size
```

