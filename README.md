# Only Focus

A Flutter-based mobile application designed to help users stay focused while reading articles, research papers, and educational content from various sources.

## Features

### 📚 Content Aggregation
- Fetches articles from 50+ RSS feeds across 16 categories
- Sources include: BBC, CNN, TechCrunch, Hacker News, arXiv, Wikipedia, and more
- 450+ unique articles after deduplication
- Auto-refresh every 8 hours with instant cached feed display
- Smart scroll-based refresh (refreshes at 60% scroll)

### 🔍 Discovery & Search
- **Discover Search**: Combines Wikipedia and DuckDuckGo web search
- **Wiki Search**: Direct Wikipedia article search
- **OCR Support**: Extract text from images and search
- Search history with individual delete and "Clear All" options
- Category filtering across 16 topics

### 📖 Reading Experience
- Built-in WebView reader with progress tracking
- **Text-to-Speech (TTS)**: Read full articles aloud with play/pause/resume controls
- **AI Summaries**: Generate 3-point summaries using Groq API
- TTS for AI summaries
- Bookmark articles for later reading
- Reading progress preservation

### 📝 Notes & Organization
- Create notes linked to articles
- Rich text editing support
- Dark mode compatible note editor
- Persistent storage with Isar database

### ⏱️ Focus Timer
- Pomodoro-style focus sessions
- Custom duration (1-180 minutes)
- Track focus time and productivity

### ⭐ Gamification
- Star system: Earn 5 stars per article read
- Daily streak tracking
- Weekly star leaderboard
- Profile statistics: Articles read, Day Streak, Minutes, Weekly Stars

### 🎨 UI/UX
- Light and Dark theme support
- Theme-aware colors for all components
- Smooth animations and transitions
- Material Design 3

### 🔐 Authentication
- Email/Password authentication
- Google Sign-In
- Anonymous authentication
- User data isolation (local data cleared on user switch/logout)

### 🤖 Agentic AI — Niko
- **Niko**, a LangGraph ReAct agent built on a Groq LLM ladder
- **RAG over your knowledge base**: saved articles sync automatically into a local Chroma vector store, and Niko answers with cited sources
- **Self-improving long-term memory**: every chat is distilled into durable facts (preferences, goals, interests) that personalize future answers
- **Document upload**: index PDF, DOCX, TXT, Markdown, JSON, CSV and code files
- **Vision**: multimodal image analysis (describe, read text, explain diagrams/charts)
- **Token-by-token streaming** chat over Server-Sent Events
- **Model ladder + key rotation**: auto-falls back across models and API keys when the free tier rate-limits
- **Optional MCP server integration** for external tool access
- Memory and knowledge base are scoped per Firebase user, viewable/deletable from the app

## Tech Stack

### Frontend
- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Local Database**: Isar
- **HTTP Client**: Dio
- **WebView**: flutter_inappwebview
- **TTS**: flutter_tts
- **OCR**: google_mlkit_text_recognition

### Backend
- **FastAPI**: Python API server (`backend/`)
- **LangGraph**: ReAct agent orchestration (Niko)
- **Chroma**: persistent vector store (documents + long-term memory)
- **LangChain**: tools, MCP adapters, text splitting
- **Firebase Authentication**: User management
- **Cloud Firestore**: User profiles, reading history, rewards
- **Cloud Functions**: Star calculation, AI summaries, badge awards

### APIs & Services
- **Groq API**: AI-powered article summaries + Niko agent LLM (model ladder with key rotation)
- **NewsAPI**: News articles
- **arXiv API**: Research papers
- **Wikipedia API**: Encyclopedia articles
- **DuckDuckGo**: Web search
- **RSS Feeds**: 50+ category-specific feeds
- **all-MiniLM-L6-v2 (ONNX)**: local embeddings, no API key needed

## Project Structure

```
lib/
├── core/
│   ├── constants/        # Colors, text styles, API endpoints
│   ├── services/         # TTS, OCR, AI, cache, search history
│   └── utils/            # Helper functions
├── data/
│   ├── models/           # Article, User, Note, Badge models
│   ├── repositories/     # Data layer abstraction
│   └── sources/          # RSS, API, and web scraping sources
├── providers/            # Riverpod state management
└── ui/
    ├── auth/             # Login, signup screens
    ├── home/             # Main feed screen
    ├── discover/         # Search and discovery
    ├── reader/           # Article reader with TTS
    ├── bookmarks/        # Saved articles
    ├── notes/            # Note editor
    ├── focus/            # Focus timer
    └── profile/          # User profile and stats
```

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0 or higher)
- Android Studio / Xcode
- Firebase account
- Python 3.11+ (for the Niko backend)
- Groq API key (for AI summaries and the Niko agent)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Rokibul1022/only_focus.git
   cd only_focus
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add Android/iOS apps to your Firebase project
   - Download `google-services.json` (Android) and place in `android/app/`
   - Download `GoogleService-Info.plist` (iOS) and place in `ios/Runner/`
   - Enable Authentication (Email/Password, Google, Anonymous)
   - Create Firestore database with rules from `firestore.rules`

4. **Add API Keys**
   
   Edit `lib/core/constants/api_endpoints.dart`:
   ```dart
   static const String groqApiKey = 'YOUR_GROQ_API_KEY';
   static const String openRouterApiKey = 'YOUR_OPENROUTER_API_KEY';
   static const String newsApiKey = 'YOUR_NEWSAPI_KEY';
   ```

5. **Deploy Cloud Functions** (Optional)
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

6. **Run the Backend (for Niko agent)**
   ```bash
   cd backend
   python -m venv .venv
   .venv\Scripts\activate        # Windows
   pip install -r requirements.txt
   cp .env.example .env          # add GROQ_KEY_1..3 (and optionally more)
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```
   - Optional MCP servers: copy `mcp_servers.example.json` to `mcp_servers.json` and configure.
   - Point the app at the backend:
     ```bash
     flutter run --dart-define=API_BASE_URL=http://<PC-LAN-IP>:8000
     ```

7. **Run the app**
   ```bash
   flutter run
   ```

## Configuration

### Categories
The app supports 16 content categories:
- Technology
- Science
- Space
- Medicine
- World
- Economics
- Philosophy
- Business
- Environment
- AI & Machine Learning
- Cybersecurity
- Energy
- Psychology
- History
- Education
- Research Papers

### Content Sources
- **News**: BBC, CNN, Reuters, TechCrunch, The Verge
- **Tech**: Hacker News, Ars Technica, Wired
- **Science**: arXiv, Nature RSS, Science Daily
- **General**: Google News, Wikipedia

## Performance Optimizations

- **Parallel Fetching**: All RSS feeds fetched simultaneously with timeouts
- **HTTP Connection Pooling**: Reuses connections for 80% less overhead
- **Batch Database Writes**: Single transaction instead of 100+ individual writes
- **Async Deduplication**: Hash-based algorithm for fast duplicate removal
- **Instant Cache Display**: Shows cached feed immediately on startup
- **Smart Refresh**: Auto-refresh at 60% scroll and every 8 hours

## Data Isolation

- Local Isar database stores bookmarks and notes per user
- Data automatically cleared when user signs out or switches accounts
- Search results isolated from home feed using `contentType` flag

## Dark Mode

All screens support dark mode with theme-aware colors:
- Text fields use `Theme.of(context).cardColor`
- Borders use `Theme.of(context).dividerColor`
- Focus states use `AppColors.primary`

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Contact

**Developer**: Rokibul Islam  
**GitHub**: [@Rokibul1022](https://github.com/Rokibul1022)  
**Repository**: [only_focus](https://github.com/Rokibul1022/only_focus)

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Groq for AI API
- All open-source contributors

---

**Note**: Remember to add your own API keys before running the app. Never commit API keys to version control.
