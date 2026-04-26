# Database Structure for Social Features

## Collections Overview

### 1. users
Main user profile collection with enhanced fields for social features.

**Fields:**
- `uid` (string) - User ID
- `displayName` (string) - User's display name
- `email` (string) - User's email
- `photoUrl` (string, optional) - Profile photo URL
- `bio` (string, optional) - User bio/description
- `country` (string, optional) - User's country
- `preferredCategories` (array<string>) - Selected interest categories
- `isOnline` (boolean) - Online status
- `createdAt` (timestamp) - Account creation date
- `lastActiveAt` (timestamp) - Last activity timestamp
- `totalStars` (number) - Total stars earned
- `weeklyStars` (number) - Stars earned this week
- `currentRank` (string) - Current rank (Novice, Reader, Scholar, Expert, Master, Legend)
- `rankIndex` (number) - Numeric rank index
- `streakDays` (number) - Current reading streak
- `longestStreak` (number) - Longest streak achieved
- `lastReadDate` (string) - Last read date (YYYY-MM-DD)
- `totalArticlesRead` (number) - Total articles read
- `totalResearchPapersRead` (number) - Total research papers read
- `totalReadingMinutes` (number) - Total reading time
- `totalFocusSessions` (number) - Total focus sessions completed
- `readingPersona` (string) - Reading personality type
- `fcmToken` (string, optional) - Firebase Cloud Messaging token
- `notificationsEnabled` (boolean) - Notification preferences

**Indexes Required:**
- `preferredCategories` (array-contains)
- `isOnline` (ascending)
- `lastActiveAt` (descending)

---

### 2. friend_requests
Manages friend request lifecycle.

**Fields:**
- `senderId` (string) - User who sent the request
- `receiverId` (string) - User who received the request
- `status` (string) - 'pending', 'accepted', 'rejected'
- `createdAt` (timestamp) - Request creation time
- `respondedAt` (timestamp, optional) - Response time

**Indexes Required:**
- `receiverId` + `status` (composite)
- `senderId` + `status` (composite)
- `createdAt` (descending)

---

### 3. friends
Stores established friendships.

**Fields:**
- `user1_id` (string) - First user ID
- `user2_id` (string) - Second user ID
- `createdAt` (timestamp) - Friendship creation time

**Indexes Required:**
- `user1_id` (ascending)
- `user2_id` (ascending)

---

### 4. posts
User-generated content posts.

**Fields:**
- `userId` (string) - Post author ID
- `title` (string) - Post title
- `description` (string) - Post description
- `imageUrls` (array<string>) - Array of image URLs (1-10 images)
- `status` (string) - 'pending', 'approved', 'rejected'
- `createdAt` (timestamp) - Post creation time
- `reviewedAt` (timestamp, optional) - Review completion time
- `likesCount` (number) - Number of likes
- `commentsCount` (number) - Number of comments
- `rejectionReason` (string, optional) - Reason if rejected

**Subcollections:**
- `likes/{userId}` - Users who liked the post
  - `userId` (string)
  - `likedAt` (timestamp)

**Indexes Required:**
- `status` + `createdAt` (composite, descending)
- `userId` + `createdAt` (composite, descending)

---

## Friend Matching Algorithm

The system calculates a match score (0.0 to 1.0) based on:

1. **Primary Category Match (+30%)**: Same first category in preferredCategories
2. **Shared Categories (+15% each)**: Each additional matching category
3. **Recent Activity (+10%)**: Active within last 24 hours
4. **Same Country (+10%)**: Matching country field

**Example:**
```
User A: ['Technology', 'AI & Machine Learning', 'Science']
User B: ['Technology', 'AI & Machine Learning', 'Business']

Score calculation:
- Primary match (Technology): +30%
- Shared category (AI & ML): +15%
- Both active today: +10%
- Same country: +10%
Total: 65% match
```

---

## Firebase Setup Steps

### 1. Create Firestore Indexes

Run these commands in Firebase Console or using Firebase CLI:

```bash
# Friend requests by receiver and status
firebase firestore:indexes:create \
  --collection-group=friend_requests \
  --field=receiverId --field=status --field=createdAt:desc

# Friend requests by sender and status
firebase firestore:indexes:create \
  --collection-group=friend_requests \
  --field=senderId --field=status --field=createdAt:desc

# Posts by status and creation time
firebase firestore:indexes:create \
  --collection-group=posts \
  --field=status --field=createdAt:desc

# Posts by user and creation time
firebase firestore:indexes:create \
  --collection-group=posts \
  --field=userId --field=createdAt:desc
```

### 2. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 3. Setup Firebase Storage

Enable Firebase Storage in Firebase Console and set up rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /posts/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 4. Enable Required Firebase Services

In Firebase Console, enable:
- ✅ Authentication (Email/Password, Google Sign-In)
- ✅ Firestore Database
- ✅ Firebase Storage
- ✅ Cloud Functions (for post moderation)
- ✅ Cloud Messaging (for notifications)

---

## Cloud Functions for Post Moderation

The app includes automatic post review. In production, enhance with:

1. **Google Cloud Vision API** - Image content analysis
2. **Perspective API** - Text toxicity detection
3. **Custom ML Models** - Content classification

Example Cloud Function (already in `functions/index.js`):

```javascript
exports.reviewPost = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data();
    
    // Call moderation APIs
    const isAppropriate = await moderateContent(post);
    
    if (isAppropriate) {
      await snap.ref.update({
        status: 'approved',
        reviewedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } else {
      await snap.ref.update({
        status: 'rejected',
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectionReason: 'Content violates guidelines'
      });
    }
  });
```

---

## Data Migration

If you have existing users, run this migration:

```javascript
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function migrateUsers() {
  const users = await db.collection('users').get();
  
  const batch = db.batch();
  users.docs.forEach(doc => {
    batch.update(doc.ref, {
      preferredCategories: [],
      photoUrl: null,
      bio: null,
      country: null,
      isOnline: false
    });
  });
  
  await batch.commit();
  console.log('Migration complete!');
}

migrateUsers();
```

---

## Security Considerations

1. **Profile Privacy**: Users can see other profiles for friend discovery
2. **Post Moderation**: All posts reviewed before publishing
3. **Friend Requests**: Only sender and receiver can see requests
4. **Data Validation**: Firestore rules enforce data integrity
5. **Image Storage**: User-specific folders in Firebase Storage

---

## Performance Optimization

1. **Pagination**: Load posts and friends in batches
2. **Caching**: Cache friend lists and suggestions locally
3. **Indexes**: All queries use composite indexes
4. **Image Optimization**: Compress images before upload
5. **Lazy Loading**: Load user details on demand

---

## Testing Checklist

- [ ] User can select categories during onboarding
- [ ] Friend suggestions appear based on matching categories
- [ ] Match percentage calculates correctly
- [ ] Friend requests can be sent and received
- [ ] Friend requests can be accepted/rejected
- [ ] Friends list shows online status
- [ ] Posts can be created with 1-10 images
- [ ] Posts are auto-reviewed within seconds
- [ ] Approved posts appear in feed
- [ ] User profile shows their posts
- [ ] Profile displays all stats correctly
- [ ] Firestore rules prevent unauthorized access
