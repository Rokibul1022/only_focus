import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _discoverHistoryKey = 'discover_search_history';
  static const String _wikiHistoryKey = 'wiki_search_history';
  static const int _maxHistoryItems = 20;

  Future<List<String>> getDiscoverHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_discoverHistoryKey) ?? [];
  }

  Future<void> addDiscoverHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final history = await getDiscoverHistory();
    
    history.remove(query);
    history.insert(0, query);
    
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    await prefs.setStringList(_discoverHistoryKey, history);
  }

  Future<void> removeDiscoverHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getDiscoverHistory();
    history.remove(query);
    await prefs.setStringList(_discoverHistoryKey, history);
  }

  Future<void> clearDiscoverHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_discoverHistoryKey);
  }

  Future<List<String>> getWikiHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_wikiHistoryKey) ?? [];
  }

  Future<void> addWikiHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final history = await getWikiHistory();
    
    history.remove(query);
    history.insert(0, query);
    
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    await prefs.setStringList(_wikiHistoryKey, history);
  }

  Future<void> removeWikiHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWikiHistory();
    history.remove(query);
    await prefs.setStringList(_wikiHistoryKey, history);
  }

  Future<void> clearWikiHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wikiHistoryKey);
  }
}
