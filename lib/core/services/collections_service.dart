import 'package:isar/isar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/article_collection.dart';
import '../../data/models/article.dart';

class CollectionsService {
  final Isar _isar;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  CollectionsService(this._isar);
  
  // Create collection
  Future<ArticleCollection> createCollection({
    required String name,
    String? description,
    String? ownerId,
    String? color,
    String? icon,
  }) async {
    final collection = ArticleCollection.create(
      name: name,
      description: description,
      ownerId: ownerId,
      color: color,
      icon: icon,
    );
    
    await _isar.writeTxn(() async {
      await _isar.articleCollections.put(collection);
    });
    
    // Sync to Firestore if owner exists
    if (ownerId != null) {
      await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('collections')
          .doc(collection.collectionId)
          .set(collection.toFirestore());
    }
    
    return collection;
  }
  
  // Get all collections
  Future<List<ArticleCollection>> getAllCollections() async {
    return await _isar.articleCollections.where().findAll();
  }
  
  // Get collection by ID
  Future<ArticleCollection?> getCollection(String collectionId) async {
    return await _isar.articleCollections
        .filter()
        .collectionIdEqualTo(collectionId)
        .findFirst();
  }
  
  // Add article to collection
  Future<void> addArticleToCollection(String collectionId, String articleId) async {
    try {
      final collection = await getCollection(collectionId);
      if (collection == null) {
        print('Collection not found: $collectionId');
        return;
      }
      
      if (!collection.articleIds.contains(articleId)) {
        collection.articleIds.add(articleId);
        collection.articleCount = collection.articleIds.length;
        collection.updatedAt = DateTime.now();
        
        await _isar.writeTxn(() async {
          await _isar.articleCollections.put(collection);
        });
        
        print('Article added to collection successfully');
        
        // Sync to Firestore
        if (collection.ownerId != null) {
          await _firestore
              .collection('users')
              .doc(collection.ownerId)
              .collection('collections')
              .doc(collectionId)
              .update({
            'articleIds': collection.articleIds,
            'articleCount': collection.articleCount,
            'updatedAt': collection.updatedAt.toIso8601String(),
          });
        }
      } else {
        print('Article already in collection');
      }
    } catch (e) {
      print('Error adding article to collection: $e');
      rethrow;
    }
  }
  
  // Remove article from collection
  Future<void> removeArticleFromCollection(String collectionId, String articleId) async {
    final collection = await getCollection(collectionId);
    if (collection == null) return;
    
    collection.articleIds.remove(articleId);
    collection.articleCount = collection.articleIds.length;
    collection.updatedAt = DateTime.now();
    
    await _isar.writeTxn(() async {
      await _isar.articleCollections.put(collection);
    });
    
    // Sync to Firestore
    if (collection.ownerId != null) {
      await _firestore
          .collection('users')
          .doc(collection.ownerId)
          .collection('collections')
          .doc(collectionId)
          .update({
        'articleIds': collection.articleIds,
        'articleCount': collection.articleCount,
        'updatedAt': collection.updatedAt.toIso8601String(),
      });
    }
  }
  
  // Get articles in collection
  Future<List<Article>> getCollectionArticles(String collectionId) async {
    final collection = await getCollection(collectionId);
    if (collection == null) return [];
    
    final articles = <Article>[];
    for (final articleId in collection.articleIds) {
      final article = await _isar.articles
          .filter()
          .idEqualTo(articleId)
          .findFirst();
      if (article != null) {
        articles.add(article);
      }
    }
    
    return articles;
  }
  
  // Share collection
  Future<void> shareCollection(String collectionId, String userId) async {
    final collection = await getCollection(collectionId);
    if (collection == null) return;
    
    if (!collection.sharedWith.contains(userId)) {
      collection.sharedWith.add(userId);
      collection.updatedAt = DateTime.now();
      
      await _isar.writeTxn(() async {
        await _isar.articleCollections.put(collection);
      });
      
      // Sync to Firestore
      if (collection.ownerId != null) {
        await _firestore
            .collection('users')
            .doc(collection.ownerId)
            .collection('collections')
            .doc(collectionId)
            .update({
          'sharedWith': collection.sharedWith,
          'updatedAt': collection.updatedAt.toIso8601String(),
        });
      }
    }
  }
  
  // Make collection public
  Future<void> togglePublic(String collectionId) async {
    final collection = await getCollection(collectionId);
    if (collection == null) return;
    
    collection.isPublic = !collection.isPublic;
    collection.updatedAt = DateTime.now();
    
    await _isar.writeTxn(() async {
      await _isar.articleCollections.put(collection);
    });
    
    // Sync to Firestore
    if (collection.ownerId != null) {
      await _firestore
          .collection('users')
          .doc(collection.ownerId)
          .collection('collections')
          .doc(collectionId)
          .update({
        'isPublic': collection.isPublic,
        'updatedAt': collection.updatedAt.toIso8601String(),
      });
    }
  }
  
  // Delete collection
  Future<void> deleteCollection(String collectionId) async {
    final collection = await getCollection(collectionId);
    if (collection == null) return;
    
    await _isar.writeTxn(() async {
      await _isar.articleCollections.delete(collection.id);
    });
    
    // Delete from Firestore
    if (collection.ownerId != null) {
      await _firestore
          .collection('users')
          .doc(collection.ownerId)
          .collection('collections')
          .doc(collectionId)
          .delete();
    }
  }
  
  // Update collection
  Future<void> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    String? color,
    String? icon,
  }) async {
    final collection = await getCollection(collectionId);
    if (collection == null) return;
    
    if (name != null) collection.name = name;
    if (description != null) collection.description = description;
    if (color != null) collection.color = color;
    if (icon != null) collection.icon = icon;
    collection.updatedAt = DateTime.now();
    
    await _isar.writeTxn(() async {
      await _isar.articleCollections.put(collection);
    });
    
    // Sync to Firestore
    if (collection.ownerId != null) {
      await _firestore
          .collection('users')
          .doc(collection.ownerId)
          .collection('collections')
          .doc(collectionId)
          .update(collection.toFirestore());
    }
  }
  
  // Get shared collections
  Future<List<ArticleCollection>> getSharedCollections(String userId) async {
    final snapshot = await _firestore
        .collectionGroup('collections')
        .where('sharedWith', arrayContains: userId)
        .get();
    
    final collections = <ArticleCollection>[];
    for (final doc in snapshot.docs) {
      collections.add(ArticleCollection.fromFirestore(doc.data()));
    }
    
    return collections;
  }
  
  // Get public collections
  Future<List<ArticleCollection>> getPublicCollections() async {
    final snapshot = await _firestore
        .collectionGroup('collections')
        .where('isPublic', isEqualTo: true)
        .limit(20)
        .get();
    
    final collections = <ArticleCollection>[];
    for (final doc in snapshot.docs) {
      collections.add(ArticleCollection.fromFirestore(doc.data()));
    }
    
    return collections;
  }
}
