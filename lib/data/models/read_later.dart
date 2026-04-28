import 'package:isar/isar.dart';

part 'read_later.g.dart';

@collection
class ReadLater {
  Id id = Isar.autoIncrement;
  
  late String articleId;
  late DateTime addedAt;
  int priority = 0; // 0=low, 1=medium, 2=high
  String? note;
  DateTime? scheduledFor;
  bool isRead = false;
  
  // Smart sorting factors
  int estimatedReadTime = 5; // minutes
  double relevanceScore = 0.0;
  List<String> tags = [];
  
  ReadLater();
  
  factory ReadLater.create({
    required String articleId,
    int priority = 0,
    String? note,
    DateTime? scheduledFor,
    int estimatedReadTime = 5,
  }) {
    return ReadLater()
      ..articleId = articleId
      ..addedAt = DateTime.now()
      ..priority = priority
      ..note = note
      ..scheduledFor = scheduledFor
      ..estimatedReadTime = estimatedReadTime;
  }
}
