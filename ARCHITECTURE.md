# ONLY FOCUS - Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ONLY FOCUS APP                              │
│                    Distraction-Free Reading                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          PRESENTATION LAYER                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │  Login   │  │  Signup  │  │   Home   │  │  Reader  │          │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Screen  │          │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │Bookmarks │  │ Profile  │  │ Discover │  │  Focus   │          │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Screen  │          │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │
│                                                                     │
│  ┌─────────────────────────────────────────────────────┐          │
│  │           Shared Widgets (Article Card, etc.)       │          │
│  └─────────────────────────────────────────────────────┘          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      STATE MANAGEMENT (Riverpod)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │    Auth      │  │     Feed     │  │    Reward    │            │
│  │   Provider   │  │   Provider   │  │   Provider   │            │
│  └──────────────┘  └──────────────┘  └──────────────┘            │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐                               │
│  │    Focus     │  │    Theme     │                               │
│  │   Provider   │  │   Provider   │                               │
│  └──────────────┘  └──────────────┘                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BUSINESS LOGIC LAYER                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────┐          │
│  │                   Repositories                       │          │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  │          │
│  │  │     Feed     │  │     User     │  │ Bookmark │  │          │
│  │  │  Repository  │  │  Repository  │  │Repository│  │          │
│  │  └──────────────┘  └──────────────┘  └──────────┘  │          │
│  └─────────────────────────────────────────────────────┘          │
│                                                                     │
│  ┌─────────────────────────────────────────────────────┐          │
│  │                     Services                         │          │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │          │
│  │  │  Cache   │  │  Reader  │  │  Focus   │          │          │
│  │  │ Service  │  │ Service  │  │ Service  │          │          │
│  │  └──────────┘  └──────────┘  └──────────┘          │          │
│  │  ┌──────────┐  ┌──────────┐                        │          │
│  │  │   TTS    │  │ Ambient  │                        │          │
│  │  │ Service  │  │ Service  │                        │          │
│  │  └──────────┘  └──────────┘                        │          │
│  └─────────────────────────────────────────────────────┘          │
│                                                                     │
│  ┌─────────────────────────────────────────────────────┐          │
│  │                      Utilities                       │          │
│  │  ┌──────────────┐  ┌──────────────┐                │          │
│  │  │     Star     │  │     Date     │                │          │
│  │  │  Calculator  │  │    Utils     │                │          │
│  │  └──────────────┘  └──────────────┘                │          │
│  └─────────────────────────────────────────────────────┘          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           DATA LAYER                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────┐          │
│  │                  Data Models                         │          │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │          │
│  │  │ Article  │  │  User    │  │  Reward  │          │          │
│  │  │  Model   │  │ Profile  │  │  Event   │          │          │
│  │  └──────────┘  └──────────┘  └──────────┘          │          │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │          │
│  │  │  Focus   │  │  Badge   │  │ Reading  │          │          │
│  │  │ Session  │  │  Model   │  │   Goal   │          │          │
│  │  └──────────┘  └──────────┘  └──────────┘          │          │
│  └─────────────────────────────────────────────────────┘          │
│                                                                     │
│  ┌─────────────────────────────────────────────────────┐          │
│  │               Content Sources                        │          │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │          │
│  │  │  Hacker  │  │  arXiv   │  │ NewsAPI  │          │          │
│  │  │   News   │  │  Source  │  │  Source  │          │          │
│  │  └──────────┘  └──────────┘  └──────────┘          │          │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │          │
│  │  │  Google  │  │ PubMed   │  │ Semantic │          │          │
│  │  │   News   │  │  Source  │  │ Scholar  │          │          │
│  │  └──────────┘  └──────────┘  └──────────┘          │          │
│  └─────────────────────────────────────────────────────┘          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        STORAGE & BACKEND                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────┐         ┌──────────────────────┐        │
│  │   Local Storage      │         │   Firebase Backend   │        │
│  │   ┌──────────────┐   │         │   ┌──────────────┐   │        │
│  │   │     Isar     │   │         │   │  Firestore   │   │        │
│  │   │   Database   │   │         │   │   Database   │   │        │
│  │   └──────────────┘   │         │   └──────────────┘   │        │
│  │   ┌──────────────┐   │         │   ┌──────────────┐   │        │
│  │   │    Hive      │   │         │   │    Cloud     │   │        │
│  │   │   Storage    │   │         │   │  Functions   │   │        │
│  │   └──────────────┘   │         │   └──────────────┘   │        │
│  │   ┌──────────────┐   │         │   ┌──────────────┐   │        │
│  │   │   Secure     │   │         │   │  Firebase    │   │        │
│  │   │   Storage    │   │         │   │     Auth     │   │        │
│  │   └──────────────┘   │         │   └──────────────┘   │        │
│  │   ┌──────────────┐   │         │   ┌──────────────┐   │        │
│  │   │    Shared    │   │         │   │     FCM      │   │        │
│  │   │ Preferences  │   │         │   │ Messaging    │   │        │
│  │   └──────────────┘   │         │   └──────────────┘   │        │
│  └──────────────────────┘         └──────────────────────┘        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        EXTERNAL SERVICES                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │  Groq API    │  │  OpenRouter  │  │   NewsAPI    │            │
│  │ (AI Summary) │  │     API      │  │     API      │            │
│  └──────────────┘  └──────────────┘  └──────────────┘            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════════
                            DATA FLOW
═══════════════════════════════════════════════════════════════════════

1. USER AUTHENTICATION FLOW:
   User → Login Screen → Auth Provider → Firebase Auth → User Profile

2. ARTICLE FEED FLOW:
   Content Sources → Feed Repository → Cache Service → Isar DB
                                    ↓
   Feed Provider → Home Screen → Article Cards → User

3. ARTICLE READING FLOW:
   User → Article Card → Reader Screen → WebView
                                      ↓
   Reading Progress → Cache Service → Isar DB
                                      ↓
   Cloud Function → Firestore → User Profile Update

4. STAR REWARD FLOW:
   Article Read (>60%) → onArticleRead Cloud Function
                                      ↓
   Star Calculation → Firestore Update → User Profile
                                      ↓
   Rank Check → Badge Check → FCM Notification (if rank up)

5. OFFLINE-FIRST FLOW:
   App Launch → Load from Isar Cache → Display Feed
                                      ↓
   Background Sync → Fetch Fresh Articles → Update Cache


═══════════════════════════════════════════════════════════════════════
                         KEY TECHNOLOGIES
═══════════════════════════════════════════════════════════════════════

Frontend:
  • Flutter 3.x (Dart 3.x)
  • Riverpod (State Management)
  • Go Router (Navigation)
  • Material 3 (Design System)

Local Storage:
  • Isar (Primary Database)
  • Hive (Fallback)
  • Shared Preferences (Settings)
  • Secure Storage (API Keys)

Backend:
  • Firebase Authentication
  • Cloud Firestore
  • Cloud Functions (Node.js 20)
  • Firebase Cloud Messaging

Content:
  • Hacker News API
  • arXiv API
  • NewsAPI.org
  • Google News RSS
  • Groq API (AI Summaries)

UI/UX:
  • Google Fonts (Inter, Merriweather)
  • WebView (Article Reader)
  • Custom Painters (Heatmap)
  • Flutter TTS (Text-to-Speech)


═══════════════════════════════════════════════════════════════════════
                      SECURITY & PRIVACY
═══════════════════════════════════════════════════════════════════════

✓ All user writes go through Cloud Functions (server-validated)
✓ Firestore security rules prevent direct client writes
✓ API keys stored in secure storage
✓ User data stays in private Firestore subcollections
✓ No social mechanics or data sharing
✓ Anonymous mode available
✓ Offline-first architecture (data stays local)


═══════════════════════════════════════════════════════════════════════
                      PERFORMANCE TARGETS
═══════════════════════════════════════════════════════════════════════

• App Launch: < 2 seconds (mid-range Android)
• Feed Load: < 1.5 seconds (WiFi)
• Reader Open: < 500ms
• Offline Mode: Full functionality after initial load
• Cache Size: Max 500 articles locally
• Background Sync: Every 30-60 minutes


═══════════════════════════════════════════════════════════════════════
                         SCALABILITY
═══════════════════════════════════════════════════════════════════════

Current Architecture Supports:
  • 10,000+ concurrent users
  • 1M+ articles in Firestore
  • 500 articles cached per user
  • Real-time leaderboard updates
  • Scheduled weekly resets
  • Badge system with unlimited badges
  • Unlimited reading history per user

Firebase Free Tier Limits:
  • 50K Firestore reads/day
  • 20K Firestore writes/day
  • 2M Cloud Function invocations/month
  • Unlimited Authentication
  • Unlimited FCM messages

For production scale, upgrade to Blaze plan (pay-as-you-go).
