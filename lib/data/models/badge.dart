import 'package:cloud_firestore/cloud_firestore.dart';

class Badge {
  final String badgeId;
  final String badgeKey;
  final String name;
  final String description;
  final String category; // 'common' | 'rare' | 'epic' | 'legendary'
  final DateTime earnedAt;
  final int starsBonus;
  final bool displayed;
  
  Badge({
    required this.badgeId,
    required this.badgeKey,
    required this.name,
    required this.description,
    required this.category,
    required this.earnedAt,
    required this.starsBonus,
    this.displayed = true,
  });
  
  factory Badge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Badge(
      badgeId: doc.id,
      badgeKey: data['badgeKey'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'common',
      earnedAt: (data['earnedAt'] as Timestamp).toDate(),
      starsBonus: data['starsBonus'] ?? 0,
      displayed: data['displayed'] ?? true,
    );
  }
  
  Map<String, dynamic> toFirestore() => {
    'badgeKey': badgeKey,
    'name': name,
    'description': description,
    'category': category,
    'earnedAt': Timestamp.fromDate(earnedAt),
    'starsBonus': starsBonus,
    'displayed': displayed,
  };
}
