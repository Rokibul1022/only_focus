# 🚀 ONLY FOCUS - Quick Start Checklist

Follow these steps in order to get the app running:

## ✅ Step 1: Verify Flutter Installation
```bash
flutter doctor
```
Ensure all checks pass (or at least Flutter and Android toolchain).

## ✅ Step 2: Get Dependencies
```bash
cd only_focus
flutter pub get
```

## ✅ Step 3: Download Firebase Config Files

### For Android Testing:
1. Go to: https://console.firebase.google.com/project/only-focus-24cf4
2. Click "Project Settings" (gear icon)
3. Scroll to "Your apps" section
4. Click on Android app (or add one):
   - Package name: `com.onlyfocus.only_focus`
   - App nickname: `Only Focus Android`
5. Download `google-services.json`
6. Place it here: `android/app/google-services.json`

### For iOS Testing (Optional):
1. Same Firebase Console
2. Click on iOS app (or add one):
   - Bundle ID: `com.onlyfocus.onlyFocus`
   - App nickname: `Only Focus iOS`
3. Download `GoogleService-Info.plist`
4. Place it here: `ios/Runner/GoogleService-Info.plist`

## ✅ Step 4: Update Firebase Options (If Needed)

The file `lib/firebase_options.dart` has placeholder API keys. 

After downloading config files, you can optionally run:
```bash
flutterfire configure
```

This will auto-generate the correct `firebase_options.dart` file.

## ✅ Step 5: Enable Firebase Services

In Firebase Console (https://console.firebase.google.com/project/only-focus-24cf4):

1. **Authentication** → Sign-in method:
   - ✅ Enable Email/Password
   - ✅ Enable Google
   - ✅ Enable Anonymous

2. **Firestore Database** → Create database:
   - Start in **production mode**
   - Choose location closest to you
   - Click "Create"

3. **Cloud Messaging**:
   - Should be enabled by default
   - No action needed for now

## ✅ Step 6: Deploy Firestore Security Rules

Create `firestore.rules` in project root (copy from FIREBASE_SETUP.md), then:

```bash
firebase login
firebase init firestore
firebase deploy --only firestore:rules
```

## ✅ Step 7: Deploy Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

This deploys:
- `onArticleRead` - Awards stars
- `generateAISummary` - AI summaries
- `onFocusSessionComplete` - Focus rewards
- `weeklyReset` - Weekly leaderboard reset

## ✅ Step 8: Run the App

```bash
flutter run
```

Or in Android Studio/VS Code:
- Press F5 (or click Run button)
- Select your device/emulator

## ✅ Step 9: Test Core Features

1. **Sign Up**
   - Create account with email/password
   - Or use Google Sign-In
   - Or continue as Guest

2. **Browse Feed**
   - Pull down to refresh
   - Should see articles from:
     - Hacker News
     - arXiv
     - NewsAPI
     - Google News

3. **Read Article**
   - Tap any article card
   - Scroll through article
   - Check if bookmark works

4. **Check Profile**
   - Tap Profile tab
   - Should see your stats
   - Rank should be "Novice" (0 stars initially)

## 🐛 Troubleshooting

### "Default FirebaseApp is not initialized"
- ❌ Missing `google-services.json` or `GoogleService-Info.plist`
- ✅ Download from Firebase Console and place in correct location
- ✅ Run `flutter clean && flutter pub get`

### "No articles loading"
- ❌ Network issue or API rate limit
- ✅ Check internet connection
- ✅ NewsAPI has 100 req/day limit (might be exceeded)
- ✅ Try pull-to-refresh

### "Cloud Functions not found"
- ❌ Functions not deployed
- ✅ Run `firebase deploy --only functions`
- ✅ Check Firebase Console → Functions

### "Permission denied" in Firestore
- ❌ Security rules not deployed
- ✅ Deploy rules: `firebase deploy --only firestore:rules`

### Build errors
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## 📊 Expected Behavior

### First Launch:
- Login screen appears
- Can sign up or sign in
- After auth, redirected to Home feed

### Home Feed:
- Shows ~65 articles from 4 sources
- Pull-to-refresh works
- "Load More" button at bottom
- Stars shown in app bar (0 initially)

### Reader:
- Article opens in WebView
- Progress bar at top
- Back button, bookmark, share icons
- Scrolling updates progress

### Profile:
- Shows user avatar (first letter of name)
- Total stars: 0
- Rank: Novice
- Stats: All zeros initially

## 🎯 Success Criteria

You've successfully set up the app when:
- ✅ App launches without errors
- ✅ Can sign up/sign in
- ✅ Feed loads articles
- ✅ Can open and read articles
- ✅ Profile shows user info
- ✅ No Firebase errors in console

## 📝 Next Steps After Setup

See `PROJECT_SUMMARY.md` for:
- What's implemented
- What needs to be done
- Phase 1 completion tasks
- Phase 2 & 3 features

## 🆘 Need Help?

1. Check `FIREBASE_SETUP.md` for detailed Firebase instructions
2. Check `README.md` for project overview
3. Check `PROJECT_SUMMARY.md` for current status
4. Run `flutter doctor -v` for environment issues
5. Check Firebase Console logs for backend errors

---

**Estimated Setup Time: 15-30 minutes**

**Once setup is complete, you'll have a working MVP with:**
- ✅ Authentication
- ✅ Article feed from 4 sources
- ✅ Basic reader
- ✅ Profile with stats
- ✅ Offline caching
- ✅ Star system (client-side)

**Ready to build? Let's go! 🚀**
