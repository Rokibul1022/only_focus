import 'package:isar/isar.dart';

part 'article.g.dart';

@collection
class Article {
  Id isarId = Isar.autoIncrement;
  
  @Index(unique: true)
  late String id; // Unique hash of URL
  
  late String title;
  late String sourceUrl;
  late String sourceName;
  
  String? imageUrl; // Article thumbnail/cover image
  
  @Index()
  late String contentType; // 'tech_news' | 'research_paper' | 'science' | 'world'
  
  @Index()
  late String category; // 'Technology' | 'Science' | etc.
  
  late DateTime publishedAt;
  late DateTime fetchedAt;
  late int estimatedReadingMinutes;
  
  String? summary; // AI-generated, cached after first request
  String? parsedContent; // Extracted article body for offline reading
  
  List<String> tags = [];
  
  bool isBookmarked = false;
  bool isReadOffline = false;
  bool isRead = false;
  
  double feedScore = 0.0; // Computed ranking score
  
  // Reading progress
  double readingProgress = 0.0; // 0.0 to 1.0
  int? readingDurationSec;
  DateTime? lastReadAt;
  
  // Constructor
  Article();
  
  // Factory for creating from API responses
  factory Article.fromJson(Map<String, dynamic> json, String source) {
    final article = Article()
      ..id = json['id']?.toString() ?? ''
      ..title = json['title'] ?? 'Untitled'
      ..sourceUrl = json['url'] ?? ''
      ..sourceName = source
      ..imageUrl = json['imageUrl'] ?? json['urlToImage'] ?? json['image']
      ..contentType = json['contentType'] ?? 'tech_news'
      ..category = json['category'] ?? 'Technology'
      ..publishedAt = json['publishedAt'] != null 
          ? DateTime.parse(json['publishedAt']) 
          : DateTime.now()
      ..fetchedAt = DateTime.now()
      ..estimatedReadingMinutes = json['estimatedReadingMinutes'] ?? 5
      ..tags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    
    return article;
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceUrl': sourceUrl,
    'sourceName': sourceName,
    'contentType': contentType,
    'category': category,
    'publishedAt': publishedAt.toIso8601String(),
    'estimatedReadingMinutes': estimatedReadingMinutes,
    'tags': tags,
  };
}
