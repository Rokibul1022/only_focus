import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Id isarId = Isar.autoIncrement;
  
  @Index(unique: true)
  late String id;
  
  late String title;
  late String content;
  
  String? articleId; // Link to article if note is related
  String? articleTitle;
  String? articleUrl;
  
  late DateTime createdAt;
  late DateTime updatedAt;
  
  @Index()
  bool isPinned = false;
  
  List<String> tags = [];
  
  Note();
  
  factory Note.create({
    required String title,
    required String content,
    String? articleId,
    String? articleTitle,
    String? articleUrl,
    List<String>? tags,
  }) {
    final now = DateTime.now();
    return Note()
      ..id = '${now.millisecondsSinceEpoch}_${title.hashCode}'
      ..title = title
      ..content = content
      ..articleId = articleId
      ..articleTitle = articleTitle
      ..articleUrl = articleUrl
      ..createdAt = now
      ..updatedAt = now
      ..tags = tags ?? [];
  }
}
