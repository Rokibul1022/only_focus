const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();
const db = admin.firestore();

// Helper: Get day multiplier based on streak
function getDayMultiplier(streakDays) {
  if (streakDays <= 2) return 1.0;
  if (streakDays <= 6) return 1.2;
  if (streakDays <= 13) return 1.5;
  if (streakDays <= 29) return 1.7;
  return 2.0; // 30+ days
}

// Helper: Check if streak is active today
function isStreakActiveToday(lastReadDate) {
  if (!lastReadDate) return false;
  const today = new Date().toISOString().split('T')[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
  return lastReadDate === today || lastReadDate === yesterday;
}

// Helper: Compute new streak
function computeNewStreak(lastReadDate, currentStreak) {
  const today = new Date().toISOString().split('T')[0];
  
  if (!lastReadDate) return 1;
  if (lastReadDate === today) return currentStreak; // Already read today
  
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
  if (lastReadDate === yesterday) {
    return currentStreak + 1; // Continue streak
  }
  
  return 1; // Streak broken, start new
}

// Helper: Get today's ISO date
function todayISO() {
  return new Date().toISOString().split('T')[0];
}

// Helper: Get rank from total stars
function getRankFromStars(totalStars) {
  if (totalStars >= 10000) return 'Legend';
  if (totalStars >= 4000) return 'Master';
  if (totalStars >= 1500) return 'Expert';
  if (totalStars >= 500) return 'Scholar';
  if (totalStars >= 100) return 'Reader';
  return 'Novice';
}

// Helper: Get rank index
function getRankIndex(rank) {
  const ranks = { 'Legend': 5, 'Master': 4, 'Expert': 3, 'Scholar': 2, 'Reader': 1, 'Novice': 0 };
  return ranks[rank] || 0;
}

// Main function: Award stars when user reads an article
exports.onArticleRead = functions.https.onCall(async (data, context) => {
  // Validate authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { articleId, contentType, durationSec, completionPercent, title, source } = data;
  
  // Validate completion
  if (completionPercent < 60) {
    return { awarded: false, reason: 'insufficient_read' };
  }
  
  const uid = context.auth.uid;
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User profile not found');
  }
  
  const user = userDoc.data();
  
  // Check if article already read
  const existingRead = await userRef.collection('readHistory').doc(articleId).get();
  if (existingRead.exists) {
    return { awarded: false, reason: 'already_read' };
  }
  
  // Calculate stars
  const baseStars = (contentType === 'research_paper' || contentType === 'science') ? 10 : 5;
  const multiplier = getDayMultiplier(user.streakDays || 0);
  const streakBonus = isStreakActiveToday(user.lastReadDate) ? 3 : 0;
  const finalStars = Math.floor(baseStars * multiplier) + streakBonus;
  
  // Compute new streak
  const newStreak = computeNewStreak(user.lastReadDate, user.streakDays || 0);
  const newTotal = (user.totalStars || 0) + finalStars;
  const newRank = getRankFromStars(newTotal);
  const oldRank = user.currentRank || 'Novice';
  
  // Atomic batch write
  const batch = db.batch();
  
  // Add to read history
  batch.set(userRef.collection('readHistory').doc(articleId), {
    articleId,
    title: title || 'Untitled',
    source: source || 'Unknown',
    contentType,
    starsAwarded: finalStars,
    readAt: admin.firestore.FieldValue.serverTimestamp(),
    readingDurationSec: durationSec || 0,
    completionPercent,
  });
  
  // Add reward event
  batch.set(userRef.collection('rewards').doc(), {
    starsEarned: finalStars,
    baseStars,
    multiplier,
    bonusApplied: streakBonus > 0,
    reason: contentType + '_read',
    articleId,
    contentType,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    dayNumber: newStreak,
  });
  
  // Update user profile
  const updateData = {
    totalStars: admin.firestore.FieldValue.increment(finalStars),
    weeklyStars: admin.firestore.FieldValue.increment(finalStars),
    totalArticlesRead: admin.firestore.FieldValue.increment(1),
    currentRank: newRank,
    rankIndex: getRankIndex(newRank),
    streakDays: newStreak,
    longestStreak: Math.max(user.longestStreak || 0, newStreak),
    lastReadDate: todayISO(),
    lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  if (contentType === 'research_paper' || contentType === 'science') {
    updateData.totalResearchPapersRead = admin.firestore.FieldValue.increment(1);
  }
  
  if (durationSec) {
    updateData.totalReadingMinutes = admin.firestore.FieldValue.increment(Math.floor(durationSec / 60));
  }
  
  batch.update(userRef, updateData);
  
  // Update leaderboard
  batch.set(db.collection('leaderboard').doc(uid), {
    displayName: user.displayName || 'User',
    totalStars: admin.firestore.FieldValue.increment(finalStars),
    weeklyStars: admin.firestore.FieldValue.increment(finalStars),
    currentRank: newRank,
    rankIndex: getRankIndex(newRank),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  
  await batch.commit();
  
  // Check for rank-up and send notification if needed
  const rankChanged = newRank !== oldRank;
  if (rankChanged && user.fcmToken) {
    try {
      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title: `🎉 Rank Up! You're now a ${newRank}!`,
          body: `You've earned ${newTotal} total stars. Keep reading!`,
        },
        data: {
          type: 'rank_up',
          newRank,
          totalStars: newTotal.toString(),
        },
      });
    } catch (error) {
      console.error('Failed to send FCM notification:', error);
    }
  }
  
  // Check for milestone badges
  await checkAndAwardBadges(uid, user, contentType, newStreak, newTotal);
  
  return {
    awarded: true,
    starsEarned: finalStars,
    newTotal,
    rankChanged,
    newRank,
    streakDays: newStreak,
  };
});

// Helper: Check and award badges
async function checkAndAwardBadges(uid, user, contentType, streakDays, totalStars) {
  const userRef = db.collection('users').doc(uid);
  const badgesRef = userRef.collection('badges');
  
  // Check for "First Article" badge
  if ((user.totalArticlesRead || 0) === 0) {
    const firstArticleBadge = await badgesRef.doc('first_article').get();
    if (!firstArticleBadge.exists) {
      await badgesRef.doc('first_article').set({
        badgeKey: 'first_article',
        name: 'First Article',
        description: 'Read your first article',
        category: 'common',
        earnedAt: admin.firestore.FieldValue.serverTimestamp(),
        starsBonus: 10,
        displayed: true,
      });
      
      // Award bonus stars
      await userRef.update({
        totalStars: admin.firestore.FieldValue.increment(10),
      });
    }
  }
  
  // Check for "First Paper" badge
  if ((contentType === 'research_paper' || contentType === 'science') && 
      (user.totalResearchPapersRead || 0) === 0) {
    const firstPaperBadge = await badgesRef.doc('first_paper').get();
    if (!firstPaperBadge.exists) {
      await badgesRef.doc('first_paper').set({
        badgeKey: 'first_paper',
        name: 'First Paper',
        description: 'Read your first research paper',
        category: 'common',
        earnedAt: admin.firestore.FieldValue.serverTimestamp(),
        starsBonus: 20,
        displayed: true,
      });
      
      await userRef.update({
        totalStars: admin.firestore.FieldValue.increment(20),
      });
    }
  }
  
  // Check for "7-Day Scholar" badge
  if (streakDays === 7) {
    const sevenDayBadge = await badgesRef.doc('seven_day_scholar').get();
    if (!sevenDayBadge.exists) {
      await badgesRef.doc('seven_day_scholar').set({
        badgeKey: 'seven_day_scholar',
        name: '7-Day Scholar',
        description: 'Complete a 7-day reading streak',
        category: 'rare',
        earnedAt: admin.firestore.FieldValue.serverTimestamp(),
        starsBonus: 25,
        displayed: true,
      });
      
      await userRef.update({
        totalStars: admin.firestore.FieldValue.increment(25),
      });
    }
  }
  
  // Check for "30-Day Legend" badge
  if (streakDays === 30) {
    const thirtyDayBadge = await badgesRef.doc('thirty_day_legend').get();
    if (!thirtyDayBadge.exists) {
      await badgesRef.doc('thirty_day_legend').set({
        badgeKey: 'thirty_day_legend',
        name: '30-Day Legend',
        description: 'Complete a 30-day reading streak',
        category: 'epic',
        earnedAt: admin.firestore.FieldValue.serverTimestamp(),
        starsBonus: 100,
        displayed: true,
      });
      
      await userRef.update({
        totalStars: admin.firestore.FieldValue.increment(100),
      });
    }
  }
}

// Generate AI summary using Groq API
exports.generateAISummary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { articleId, articleText } = data;
  
  if (!articleText || articleText.length < 100) {
    throw new functions.https.HttpsError('invalid-argument', 'Article text too short');
  }
  
  const uid = context.auth.uid;
  const userRef = db.collection('users').doc(uid);
  
  // Check if summary already cached
  const cachedSummary = await userRef.collection('readHistory').doc(articleId).get();
  if (cachedSummary.exists && cachedSummary.data().summary) {
    return { summary: cachedSummary.data().summary, cached: true };
  }
  
  try {
    // Call Groq API
    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'mixtral-8x7b-32768',
        messages: [
          {
            role: 'system',
            content: 'You are a helpful assistant that summarizes articles into exactly 3 key takeaways. Return only a JSON array with 3 objects, each with a "point" field. Each point should be under 25 words.',
          },
          {
            role: 'user',
            content: `Summarize this article into 3 key takeaways:\n\n${articleText.substring(0, 8000)}`,
          },
        ],
        temperature: 0.3,
        max_tokens: 500,
      },
      {
        headers: {
          'Authorization': `Bearer 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`,
          'Content-Type': 'application/json',
        },
      }
    );
    
    const summaryText = response.data.choices[0].message.content;
    let summaryPoints;
    
    try {
      summaryPoints = JSON.parse(summaryText);
    } catch (e) {
      // If not valid JSON, create simple array
      summaryPoints = [
        { point: summaryText.substring(0, 100) },
        { point: 'Summary generation in progress...' },
        { point: 'Please try again in a moment.' },
      ];
    }
    
    // Cache the summary
    await userRef.collection('readHistory').doc(articleId).set({
      summary: summaryPoints,
    }, { merge: true });
    
    // Award bonus stars for using AI summary
    await userRef.update({
      totalStars: admin.firestore.FieldValue.increment(3),
    });
    
    return { summary: summaryPoints, cached: false };
  } catch (error) {
    console.error('Groq API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to generate summary');
  }
});

// Focus session complete
exports.onFocusSessionComplete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { sessionType, durationMinutes, articlesRead, goalMet } = data;
  const uid = context.auth.uid;
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  const user = userDoc.data();
  const baseStars = sessionType === 'deep_work' ? 8 : 5;
  const multiplier = getDayMultiplier(user.streakDays || 0);
  const finalStars = Math.floor(baseStars * multiplier);
  
  // Save session
  await userRef.collection('focusSessions').add({
    startTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() - durationMinutes * 60000)),
    endTime: admin.firestore.FieldValue.serverTimestamp(),
    durationMinutes,
    articlesReadDuringSession: articlesRead || 0,
    starsEarned: finalStars,
    goalMet: goalMet || false,
    sessionType,
    streakDay: user.streakDays || 0,
  });
  
  // Update user stats
  await userRef.update({
    totalStars: admin.firestore.FieldValue.increment(finalStars),
    totalFocusSessions: admin.firestore.FieldValue.increment(1),
  });
  
  return { awarded: true, starsEarned: finalStars };
});

// Weekly reset (scheduled function - runs every Monday at 00:00 UTC)
exports.weeklyReset = functions.pubsub.schedule('0 0 * * 1').onRun(async (context) => {
  const usersSnapshot = await db.collection('users').get();
  const batch = db.batch();
  
  usersSnapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { weeklyStars: 0 });
  });
  
  const leaderboardSnapshot = await db.collection('leaderboard').get();
  leaderboardSnapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { weeklyStars: 0 });
  });
  
  await batch.commit();
  console.log('Weekly reset completed');
  return null;
});
