import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  // News APIs
  static const String hackerNewsBase = 'https://hacker-news.firebaseio.com/v0';
  static const String newsApiBase = 'https://newsapi.org/v2';
  static String get newsApiKey => dotenv.env['NEWS_API_KEY'] ?? '';
  static const String guardianBase = 'https://content.guardianapis.com';
  
  // RSS Feeds
  static const String googleNewsRss = 'https://news.google.com/rss?q=technology';
  static const String bbcRss = 'https://feeds.bbci.co.uk/news/technology/rss.xml';
  static const String reutersRss = 'https://www.reutersagency.com/feed/?taxonomy=best-topics&post_type=best';
  
  // Research & Science
  static const String arxivBase = 'https://export.arxiv.org/api/query';
  static const String pubmedBase = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils';
  static const String semanticScholarBase = 'https://api.semanticscholar.org/graph/v1';
  static const String openAlexBase = 'https://api.openalex.org';
  
  // Reference
  static const String wikipediaBase = 'https://en.wikipedia.org/api/rest_v1';
  
  // AI APIs
  static const String groqApiBase = 'https://api.groq.com/openai/v1';
  static List<String> get groqApiKeys => (dotenv.env['GROQ_API_KEYS'] ?? '')
      .split(',')
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toList();
  static const String openRouterApiBase = 'https://openrouter.ai/api/v1';
  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  
  // ElevenLabs API
  static const String elevenLabsApiBase = 'https://api.elevenlabs.io/v1';
  static String get elevenLabsApiKey => dotenv.env['ELEVENLABS_API_KEY'] ?? '';
  static const String elevenLabsVoiceId = 'JBFqnCBsd6RMkjVDRZzb'; // Default voice
}
