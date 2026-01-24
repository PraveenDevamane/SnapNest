# SnapNest Setup Guide

## 🔐 Firebase Configuration (Required)

This project requires Firebase configuration files that are **not included in the repository** for security reasons.

### Option 1: Use FlutterFire CLI (Recommended)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (select your project)
flutterfire configure
```

This will automatically generate:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### Option 2: Manual Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Add Android/iOS apps to your project
4. Download the config files:
   - **Android**: Download `google-services.json` → place in `android/app/`
   - **iOS**: Download `GoogleService-Info.plist` → place in `ios/Runner/`
5. Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart` and fill in your values

## 🔑 Google Sign-In Setup

1. In Firebase Console → Authentication → Sign-in method
2. Enable **Google** provider
3. For Android, add your SHA-1 fingerprint:
   ```bash
   cd android && ./gradlew signingReport
   ```
4. Copy the SHA-1 and add it in Firebase Console → Project Settings → Your Android App

## 📱 Running the App

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run
```

## 🛡️ Security Notes

The following files contain sensitive API keys and should **NEVER** be committed:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

These are listed in `.gitignore` for protection.
