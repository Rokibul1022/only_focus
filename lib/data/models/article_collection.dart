import 'package:isar/isar.dart';

part 'article_collection.g.dart';

@collection
class ArticleCollection {
  Id id = Isar.autoIncrement;
  
  late String collectionId;
  late String name;
  String? description;
  String? coverImage;
  late List<String> articleIds;
  late DateTime createdAt;
  late DateTime updatedAt;
  
  // Sharing
  bool isPublic = false;
  List<String> sharedWith = [];
  String? ownerId;
  
  // Metadata
  int articleCount = 0;
  String? color;
  String? icon;
  
  ArticleCollection();
  
  factory ArticleCollection.create({
    required String name,
    String? description,
    String? ownerId,
    String? color,
    String? icon,
  }) {
    return ArticleCollection()
      ..collectionId = DateTime.now().millisecondsSinceEpoch.toString()
      ..name = name
      ..description = description
      ..articleIds = []
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..ownerId = ownerId
      ..color = color
      ..icon = icon;
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'collectionId': collectionId,
      'name': name,
      'description': description,
      'coverImage': coverImage,
      'articleIds': articleIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPublic': isPublic,
      'sharedWith': sharedWith,
      'ownerId': ownerId,
      'articleCount': articleCount,
      'color': color,
      'icon': icon,
    };
  }
  
  factory ArticleCollection.fromFirestore(Map<String, dynamic> data) {
    return ArticleCollection()
      ..collectionId = data['collectionId']
      ..name = data['name']
      ..description = data['description']
      ..coverImage = data['coverImage']
      ..articleIds = List<String>.from(data['articleIds'] ?? [])
      ..createdAt = DateTime.parse(data['createdAt'])
      ..updatedAt = DateTime.parse(data['updatedAt'])
      ..isPublic = data['isPublic'] ?? false
      ..sharedWith = List<String>.from(data['sharedWith'] ?? [])
      ..ownerId = data['ownerId']
      ..articleCount = data['articleCount'] ?? 0
      ..color = data['color']
      ..icon = data['icon'];
  }
}
