import 'package:isar/isar.dart';
import '../../data/models/note.dart';
import 'cache_service.dart';

class NotesService {
  final CacheService _cacheService = CacheService();
  
  Future<Isar> get isar async {
    return await _cacheService.isar;
  }
  
  // Create note
  Future<void> createNote(Note note) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.notes.put(note);
    });
  }
  
  // Get all notes
  Future<List<Note>> getAllNotes() async {
    final db = await isar;
    return await db.notes
        .where()
        .sortByUpdatedAtDesc()
        .findAll();
  }
  
  // Get note by ID
  Future<Note?> getNoteById(String id) async {
    final db = await isar;
    return await db.notes
        .filter()
        .idEqualTo(id)
        .findFirst();
  }
  
  // Get notes by article
  Future<List<Note>> getNotesByArticle(String articleId) async {
    final db = await isar;
    return await db.notes
        .filter()
        .articleIdEqualTo(articleId)
        .sortByCreatedAtDesc()
        .findAll();
  }
  
  // Get pinned notes
  Future<List<Note>> getPinnedNotes() async {
    final db = await isar;
    return await db.notes
        .filter()
        .isPinnedEqualTo(true)
        .sortByUpdatedAtDesc()
        .findAll();
  }
  
  // Update note
  Future<void> updateNote(Note note) async {
    final db = await isar;
    note.updatedAt = DateTime.now();
    await db.writeTxn(() async {
      await db.notes.put(note);
    });
  }
  
  // Delete note
  Future<void> deleteNote(String id) async {
    final db = await isar;
    final note = await getNoteById(id);
    if (note != null) {
      await db.writeTxn(() async {
        await db.notes.delete(note.isarId);
      });
    }
  }
  
  // Toggle pin
  Future<void> togglePin(String id) async {
    final note = await getNoteById(id);
    if (note != null) {
      note.isPinned = !note.isPinned;
      await updateNote(note);
    }
  }
  
  // Search notes
  Future<List<Note>> searchNotes(String query) async {
    final db = await isar;
    final lowerQuery = query.toLowerCase();
    
    return await db.notes
        .filter()
        .titleContains(lowerQuery, caseSensitive: false)
        .or()
        .contentContains(lowerQuery, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .findAll();
  }
}
