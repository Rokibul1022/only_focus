# Quick Setup Guide

## ✅ Changes Made

### Storage Solution
- ✅ **Removed Firebase Storage** (not free)
- ✅ **Using Local Phone Storage** (completely free)
- ✅ Images saved to: `/data/user/0/com.onlyfocus.only_focus/app_flutter/posts/{userId}/`

### Firestore Rules
- ✅ Complete rules in `FIRESTORE_RULES.txt`
- ✅ Copy and paste directly into Firebase Console

---

## 🚀 Setup Steps

### 1. Deploy Firestore Rules

**Option A: Firebase Console (Recommended)**
1. Go to Firebase Console → Firestore Database → Rules
2. Open `FIRESTORE_RULES.txt` file
3. Copy ALL the content
4. Paste into Firebase Console
5. Click "Publish"

**Option B: Firebase CLI**
```bash
firebase deploy --only firestore:rules
```

### 2. Create Firestore Indexes (Automatic)

**Don't create indexes manually!** Instead:

1. Run your app
2. Try these actions:
   - Go to Friends screen → Suggested tab
   - Go to Friends screen → Requests tab
   - Create a post
   - View someone's profile

3. When you see errors in console, Firebase will provide links like:
   ```
   https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes?create_composite=...
   ```

4. Click the link and Firebase will create the index automatically

**Required Indexes (will be auto-generated):**
- `friend_requests`: receiverId + status + createdAt
- `friend_requests`: senderId + status + createdAt
- `posts`: status + createdAt
- `posts`: userId + createdAt

### 3. Run the App

```bash
flutter pub get
flutter run
```

---

## 📱 How It Works

### Local Storage
- Images stored in app's private directory
- Automatically deleted when post is deleted
- No storage costs
- Fast access
- Works offline

### Image Paths
Posts store local file paths like:
```
/data/user/0/com.onlyfocus.only_focus/app_flutter/posts/user123/1714089600000_0.jpg
```

### Firestore Structure
```
posts/
  {postId}/
    - userId: "user123"
    - title: "My Post"
    - description: "Description"
    - imagePaths: ["/path/to/image1.jpg", "/path/to/image2.jpg"]
    - status: "approved"
    - createdAt: timestamp
    - likesCount: 0
```

---

## 🔒 Security

### Firestore Rules Summary
- ✅ Users can read all profiles (for friend discovery)
- ✅ Users can only edit their own profile
- ✅ Friend requests visible to sender/receiver only
- ✅ Posts readable by all, writable by owner
- ✅ Likes secured per user

### Local Storage Security
- ✅ Images in app's private directory
- ✅ Not accessible by other apps
- ✅ Deleted when app is uninstalled

---

## 🧪 Testing Checklist

1. **Friends System**
   - [ ] View suggested friends
   - [ ] Send friend request
   - [ ] Accept friend request
   - [ ] View friends list
   - [ ] Remove friend

2. **Posts System**
   - [ ] Create post with images
   - [ ] Post auto-reviewed (2 seconds)
   - [ ] View posts in profile
   - [ ] View friend's posts

3. **Profile**
   - [ ] View own profile with posts
   - [ ] View other user's profile
   - [ ] Add friend from profile

---

## ⚠️ Important Notes

1. **Indexes**: Don't create manually - let Firebase generate them automatically when you use the app

2. **Storage**: Images are stored locally on the device, not in cloud

3. **Sharing**: If users want to share posts with friends on different devices, images won't transfer (this is the tradeoff for free storage)

4. **Backup**: Local images are not backed up - they're lost if app is uninstalled

---

## 🎯 Next Steps After Setup

1. Deploy Firestore rules
2. Run the app
3. Test all features
4. Click the index creation links when they appear
5. Wait for indexes to build (1-2 minutes)
6. Test again

---

## 📞 Troubleshooting

**Error: "Missing or insufficient permissions"**
- Solution: Deploy Firestore rules from `FIRESTORE_RULES.txt`

**Error: "The query requires an index"**
- Solution: Click the link in the error message to create the index

**Images not showing**
- Solution: Check if file paths are correct in Firestore
- Verify images were saved to local storage

**Friend suggestions not appearing**
- Solution: Make sure users have selected categories in onboarding
- Check if indexes are created

---

## ✅ Ready to Use!

All features are implemented and ready. Just:
1. Copy rules from `FIRESTORE_RULES.txt` to Firebase Console
2. Run the app
3. Create indexes when prompted
4. Start using!
