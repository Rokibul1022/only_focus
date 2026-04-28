class Book {
  final String id;
  final String title;
  final String author;
  final String category;
  final String description;
  final String coverUrl;
  final String pdfUrl;
  final int pages;
  final String language;
  final DateTime publishedDate;
  
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.description,
    required this.coverUrl,
    required this.pdfUrl,
    required this.pages,
    required this.language,
    required this.publishedDate,
  });
  
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      author: json['author'] ?? 'Unknown Author',
      category: json['category'] ?? 'General',
      description: json['description'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      pdfUrl: json['pdfUrl'] ?? '',
      pages: json['pages'] ?? 0,
      language: json['language'] ?? 'English',
      publishedDate: json['publishedDate'] != null 
          ? DateTime.parse(json['publishedDate'])
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'category': category,
    'description': description,
    'coverUrl': coverUrl,
    'pdfUrl': pdfUrl,
    'pages': pages,
    'language': language,
    'publishedDate': publishedDate.toIso8601String(),
  };
}
