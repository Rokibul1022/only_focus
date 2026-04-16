# Chatbot & UI Update

## Changes Made

### 1. Focus Timer Moved to Sidebar
- **Removed** Focus Timer from bottom navigation bar (was 5th item)
- **Added** Focus Timer to app drawer/sidebar menu
- Bottom navigation now has 4 items: Home, Discover, Bookmarks, Profile

### 2. AI Chatbot Implementation
Created a modern chatbot with sentiment analysis using Groq API:

#### New Files Created:
- `lib/core/services/chatbot_service.dart` - Chatbot service with Groq API integration
- `lib/providers/chatbot_provider.dart` - State management for chat messages
- `lib/ui/shared/chatbot_widget.dart` - Modern chatbot UI component

#### Features:
- **Sentiment Analysis**: Detects user emotions (positive, negative, neutral, excited, confused, frustrated)
- **Conversation History**: Maintains context for better responses
- **Modern UI**: 
  - Expandable/collapsible chat interface
  - Gradient header with AI icon
  - Message bubbles with sentiment-aware styling
  - Smooth animations
  - Dark mode compatible
- **Smart Responses**: Uses Groq's Llama 3.1 model for intelligent replies
- **Context-Aware**: Understands it's an assistant for Only Focus app

#### Sentiment Detection:
The chatbot analyzes user input for emotional tone:
- **Excited**: "amazing", "awesome", "great", "love", "excellent", "fantastic"
- **Positive**: "good", "nice", "thanks", "helpful", "appreciate"
- **Negative**: "bad", "hate", "terrible", "awful", "worst"
- **Confused**: "confused", "don't understand", "what", "how"
- **Frustrated**: "frustrated", "annoying", "stuck", "can't", "won't work"
- **Neutral**: Default when no specific sentiment detected

### 3. Home Screen Updates
- Added chatbot widget at bottom of home screen
- Positioned as floating overlay above feed
- Added bottom padding to feed list (100px) to prevent overlap
- Chatbot is always accessible while browsing articles

### 4. App Drawer Updates
- Added "Focus Timer" menu item with timer icon
- Positioned between "Wikipedia Search" and "My Notes"

## UI/UX Improvements

### Chatbot Widget:
- **Collapsed State**: Shows compact header bar (60px height)
- **Expanded State**: Takes up 70% of screen height
- **Header**: Gradient background (primary to accent color)
- **Messages**: 
  - User messages: Right-aligned, primary color background
  - Bot messages: Left-aligned, card color with border
  - Sentiment-aware shadow colors
- **Input Field**: Rounded text field with gradient send button
- **Empty State**: Friendly prompt to start conversation

### Navigation:
- Cleaner bottom nav with 4 items instead of 5
- Focus Timer easily accessible from sidebar
- More space for main navigation items

## Technical Details

### API Integration:
- Uses Groq API with Llama 3.1 8B Instant model
- Temperature: 0.7 for balanced creativity
- Max tokens: 500 for concise responses
- Maintains last 10 messages for context

### State Management:
- Riverpod providers for reactive state
- Automatic UI updates on message send/receive
- Conversation history persistence during session

### Performance:
- Lazy loading of messages
- Smooth scroll animations
- Efficient sentiment analysis (keyword-based)
- Minimal API calls with conversation context

## Usage

### For Users:
1. Open the app and see the chatbot header at bottom of home screen
2. Tap to expand the chatbot
3. Type questions about articles, focus tips, or general queries
4. Bot responds with helpful, context-aware answers
5. Tap header again to collapse

### For Developers:
```dart
// Access chatbot service
final chatbotService = ref.read(chatbotServiceProvider);

// Send message programmatically
await ref.read(chatMessagesProvider.notifier).sendMessage("Hello!");

// Clear chat history
ref.read(chatMessagesProvider.notifier).clearChat();

// Analyze sentiment
final sentiment = chatbotService.analyzeSentiment("I love this app!");
```

## Future Enhancements

Potential improvements:
- Voice input/output integration
- Article recommendations based on chat context
- Multi-language support
- Conversation history persistence across sessions
- Quick action buttons (e.g., "Recommend an article", "Start focus session")
- Integration with reading stats and goals
- Personalized responses based on user profile

## Testing Checklist

- [x] Chatbot expands/collapses smoothly
- [x] Messages send and receive correctly
- [x] Sentiment analysis works for different inputs
- [x] Dark mode compatibility
- [x] Focus Timer accessible from sidebar
- [x] Bottom navigation works with 4 items
- [x] Feed list doesn't overlap with chatbot
- [x] Scroll behavior works correctly
- [x] API error handling
- [x] Empty state displays properly

## Notes

- Groq API key is already configured in `api_endpoints.dart`
- Chatbot uses same API key as article summarization feature
- Widget is theme-aware and adapts to light/dark mode
- Sentiment analysis is client-side (no API calls needed)
- Conversation history clears on app restart (can be persisted if needed)
