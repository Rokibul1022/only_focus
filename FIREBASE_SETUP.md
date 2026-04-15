# Firebase Setup Guide for Only Focus

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Node.js 20 installed
- Firebase project: `only-focus-24cf4`

## Step 1: Download Firebase Configuration Files

### For Android

1. Go to [Firebase Console](https://console.firebase.google.com/project/only-focus-24cf4)
2. Click on the Android app (or add one if it doesn't exist)
3. Package name: `com.onlyfocus.only_focus`
4. Download `google-services.json`
5. Place it in: `android/app/google-services.json`

### For iOS

1. Go to Firebase Console
2. Click on the iOS app (or add one if it doesn't exist)
3. Bundle ID: `com.onlyfocus.onlyFocus`
4. Download `GoogleService-Info.plist`
5. Place it in: `ios/Runner/GoogleService-Info.plist`

## Step 2: Enable Firebase Services

In Firebase Console, enable:

1. **Authentication**
   - Email/Password
   - Google Sign-In
   - Anonymous

2. **Firestore Database**
   - Start in production mode
   - Location: Choose closest to your users

3. **Cloud Functions**
   - Upgrade to Blaze plan (pay-as-you-go, but has free tier)

4. **Cloud Messaging** (for notifications)
   - Enable FCM

## Step 3: Deploy Firestore Security Rules

Create `firestore.rules` in project root:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if false; // Cloud Functions only
      
      match /rewards/{id} { 
        allow read: if request.auth.uid == uid; 
        allow write: if false; 
      }
      match /readHistory/{id} { 
        allow read: if request.auth.uid == uid; 
        allow write: if false; 
      }
      match /focusSessions/{id} { 
        allow read: if request.auth.uid == uid; 
        allow write: if false; 
      }
      match /badges/{id} { 
        allow read: if request.auth.uid == uid; 
        allow write: if false; 
      }
      match /goals/{id} { 
        allow read, write: if request.auth.uid == uid; 
      }
      match /highlights/{id} { 
        allow read, write: if request.auth.uid == uid; 
      }
    }
    
    match /leaderboard/{uid} { 
      allow read: if request.auth != null; 
      allow write: if false; 
    }
    
    match /appStats/{doc} { 
      allow read: if request.auth != null; 
      allow write: if false; 
    }
    
    match /deepDives/{id} { 
      allow read: if request.auth != null; 
      allow write: if false; 
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

## Step 4: Deploy Cloud Functions

1. **Login to Firebase**
   ```bash
   firebase login
   ```

2. **Initialize Firebase in project** (if not already done)
   ```bash
   firebase init
   ```
   - Select: Functions, Firestore
   - Choose existing project: `only-focus-24cf4`
   - Language: JavaScript
   - Use existing `functions` directory

3. **Install dependencies**
   ```bash
   cd functions
   npm install
   cd ..
   ```

4. **Deploy functions**
   ```bash
   firebase deploy --only functions
   ```

   This will deploy:
   - `onArticleRead` - Awards stars when user reads articles
   - `generateAISummary` - Generates AI summaries using Groq
   - `onFocusSessionComplete` - Awards stars for focus sessions
   - `weeklyReset` - Resets weekly leaderboard every Monday

## Step 5: Test Cloud Functions Locally

1. **Start Firebase emulators**
   ```bash
   firebase emulators:start
   ```

2. **Update Flutter app to use emulators** (for testing)
   
   In `lib/main.dart`, add after Firebase initialization:
   ```dart
   if (kDebugMode) {
     FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
     FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
     await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
   }
   ```

## Step 6: Configure Android for Firebase

1. **Update `android/build.gradle`**
   ```gradle
   buildscript {
     dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
     }
   }
   ```

2. **Update `android/app/build.gradle`**
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

3. **Ensure `google-services.json` is in place**
   ```
   android/app/google-services.json
   ```

## Step 7: Configure iOS for Firebase

1. **Open iOS project in Xcode**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Add `GoogleService-Info.plist`**
   - Drag the file into the Runner folder in Xcode
   - Ensure "Copy items if needed" is checked
   - Target: Runner

3. **Update `ios/Podfile`** (if needed)
   ```ruby
   platform :ios, '14.0'
   ```

4. **Install pods**
   ```bash
   cd ios
   pod install
   cd ..
   ```

## Step 8: Test the App

1. **Run the app**
   ```bash
   flutter run
   ```

2. **Test authentication**
   - Sign up with email/password
   - Sign in with Google
   - Try anonymous mode

3. **Test article reading**
   - Browse feed
   - Open an article
   - Scroll past 60%
   - Check if stars are awarded

4. **Check Firestore**
   - Go to Firebase Console → Firestore
   - Verify user document created
   - Check `readHistory` and `rewards` subcollections

## Troubleshooting

### "Default FirebaseApp is not initialized"
- Ensure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in place
- Clean and rebuild: `flutter clean && flutter pub get`

### "Cloud Functions not found"
- Ensure functions are deployed: `firebase deploy --only functions`
- Check function names match in Flutter code

### "Permission denied" in Firestore
- Deploy security rules: `firebase deploy --only firestore:rules`
- Ensure user is authenticated before accessing data

### API Keys Not Working
- NewsAPI: Check daily limit (100 requests/day on free tier)
- Groq API: Verify key is correct in `functions/index.js`

## Monitoring

- **Firebase Console**: Monitor usage, errors, and performance
- **Cloud Functions Logs**: `firebase functions:log`
- **Firestore Usage**: Check read/write counts to stay within free tier

## Free Tier Limits

- **Firestore**: 50K reads, 20K writes, 20K deletes per day
- **Cloud Functions**: 2M invocations, 400K GB-seconds per month
- **Authentication**: Unlimited
- **FCM**: Unlimited

For production, monitor usage and upgrade to Blaze plan if needed.

---

**Need help?** Check [Firebase Documentation](https://firebase.google.com/docs)
