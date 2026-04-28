# Deploy Firestore Rules

## Option 1: Using Firebase Console (Easiest)
1. Go to https://console.firebase.google.com
2. Select your project
3. Go to Firestore Database
4. Click on "Rules" tab
5. Copy the content from `firestore.rules` file
6. Paste it in the rules editor
7. Click "Publish"

## Option 2: Using Firebase CLI
1. Make sure Firebase CLI is installed: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Initialize (if not done): `firebase init firestore`
4. Deploy rules: `firebase deploy --only firestore:rules`

## What Changed
- Simplified app_feedback collection rules
- Now any authenticated user can create feedback
- All authenticated users can read feedback
