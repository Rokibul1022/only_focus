# 🚀 Quick Start Guide - Only Focus

## ✅ iOS Setup Complete!

All iOS configurations are done. Follow these steps to run the app:

---

## 📱 Run on iOS

### Step 1: Install Dependencies
```bash
cd /Users/rokibulislam/Desktop/only_Focus/only_focus
flutter clean
flutter pub get
```

### Step 2: Install iOS Pods
```bash
cd ios
pod install
cd ..
```

### Step 3: Run the App
```bash
# On iOS Simulator
flutter run

# Or open in Xcode
open ios/Runner.xcworkspace
```

---

## 🤖 Android Setup (Still Needed)

### Download google-services.json:
1. Go to: https://console.firebase.google.com/project/only-focus-24cf4
2. Click ⚙️ (Settings) → Project Settings
3. Scroll to "Your apps" section
4. Click on Android app (or add one if missing)
5. Download `google-services.json`
6. Place it here: `android/app/google-services.json`

### Check Package Name:
Your Android package name should be: `com.onlyfocus.only_focus`

After adding google-services.json, update this line in `lib/firebase_options.dart`:
```dart
appId: '1:1077095740725:android:YOUR_ANDROID_APP_ID',
```
Replace `YOUR_ANDROID_APP_ID` with the actual ID from google-services.json

---

## ☁️ Deploy Cloud Functions

### Step 1: Install Dependencies
```bash
cd functions
npm install
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Deploy
```bash
firebase deploy --only functions
```

---

## 🧪 Test Features

### Authentication:
- ✅ Email/Password signup
- ✅ Google Sign-In
- ✅ Anonymous login

### Core Features:
- ✅ Browse article feed
- ✅ Search & discover
- ✅ Read articles
- ✅ Bookmark articles
- ✅ Focus timer (Pomodoro/Deep Work)
- ✅ Earn stars (scroll 60% in article)
- ✅ AI summaries (Groq API)

---

## 🔑 API Keys Configured

### ✅ Groq API:
- Key: `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`
- Location: `lib/core/constants/api_endpoints.dart`
- Cloud Functions: `functions/index.js`

### ✅ NewsAPI:
- Key: `d37d935775f64881b00f3f508c66994d`
- Location: `lib/core/constants/api_endpoints.dart`

---

## 📂 Important Files

### iOS:
- ✅ `ios/Runner/GoogleService-Info.plist`
- ✅ `ios/Runner/AppDelegate.swift`
- ✅ `ios/Runner/Info.plist`

### Flutter:
- ✅ `lib/firebase_options.dart`
- ✅ `lib/main.dart`
- ✅ `lib/core/constants/api_endpoints.dart`

### Backend:
- ✅ `functions/index.js`
- ✅ `firestore.rules`

---

## 🐛 Troubleshooting

### "Firebase not initialized" error:
```bash
flutter clean
cd ios && pod install && cd ..
flutter pub get
flutter run
```

### "Google Sign-In failed":
- Check Info.plist has URL scheme
- Verify GoogleService-Info.plist is in Runner folder
- Check bundle ID matches: `com.onlyfocus.onlyFocus`

### "Cloud Functions not working":
- Deploy functions: `cd functions && firebase deploy --only functions`
- Check Firebase Console → Functions tab
- Verify Groq API key is correct

### Build errors:
```bash
# iOS
cd ios
pod deintegrate
pod install
cd ..

# Flutter
flutter clean
flutter pub get
flutter run
```

---

## 📊 Project Status

| Component | Status | Notes |
|-----------|--------|-------|
| iOS Firebase | ✅ Complete | Ready to run |
| Android Firebase | ❌ Pending | Need google-services.json |
| Groq API | ✅ Configured | AI summaries ready |
| Cloud Functions | ⚠️ Not Deployed | Run `firebase deploy` |
| App Code | ✅ Complete | 85% Phase 1 MVP |

---

## 🎯 What Works Now (iOS)

✅ User authentication (all methods)
✅ Article feed from 50+ sources
✅ Search & discovery
✅ Article reader
✅ Bookmarks
✅ Focus timer
✅ Star rewards (local)
⚠️ Cloud Functions (after deployment)
⚠️ AI Summaries (after Cloud Functions deployed)

---

## 📞 Need Help?

- Firebase Console: https://console.firebase.google.com/project/only-focus-24cf4
- FlutterFire Docs: https://firebase.flutter.dev
- Project README: `README.md`
- Architecture: `ARCHITECTURE.md`

---

**Ready to run on iOS! 🎉**

Just run: `flutter run` (after pod install)
