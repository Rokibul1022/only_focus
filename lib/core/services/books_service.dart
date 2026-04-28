import 'package:dio/dio.dart';
import '../../data/models/book.dart';

class BooksService {
  final Dio _dio = Dio();
  
  // Fetch books by category from Open Library API
  Future<List<Book>> fetchBooksByCategory(String category, {int limit = 20}) async {
    try {
      final query = category.toLowerCase().replaceAll(' ', '+');
      final response = await _dio.get(
        'https://openlibrary.org/search.json?subject=$query&limit=$limit',
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final docs = data['docs'] as List;
        
        return docs.map((doc) {
          final coverId = doc['cover_i'];
          final coverUrl = coverId != null
              ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
              : '';
          
          final key = doc['key'] as String?;
          final bookId = key?.replaceAll('/works/', '') ?? '';
          
          return Book(
            id: bookId,
            title: doc['title'] ?? 'Unknown',
            author: (doc['author_name'] as List?)?.first ?? 'Unknown Author',
            category: category,
            description: doc['first_sentence']?.toString() ?? 'No description available',
            coverUrl: coverUrl,
            pdfUrl: '', // Will be fetched when opening book
            pages: doc['number_of_pages_median'] ?? 0,
            language: doc['language']?.first ?? 'English',
            publishedDate: doc['first_publish_year'] != null
                ? DateTime(doc['first_publish_year'])
                : DateTime.now(),
          );
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('Error fetching books: $e');
      return [];
    }
  }
  
  // Search books
  Future<List<Book>> searchBooks(String query, {int limit = 20}) async {
    try {
      final searchQuery = query.replaceAll(' ', '+');
      final response = await _dio.get(
        'https://openlibrary.org/search.json?q=$searchQuery&limit=$limit',
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final docs = data['docs'] as List;
        
        return docs.map((doc) {
          final coverId = doc['cover_i'];
          final coverUrl = coverId != null
              ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
              : '';
          
          final key = doc['key'] as String?;
          final bookId = key?.replaceAll('/works/', '') ?? '';
          
          return Book(
            id: bookId,
            title: doc['title'] ?? 'Unknown',
            author: (doc['author_name'] as List?)?.first ?? 'Unknown Author',
            category: (doc['subject'] as List?)?.first ?? 'General',
            description: doc['first_sentence']?.toString() ?? 'No description available',
            coverUrl: coverUrl,
            pdfUrl: '',
            pages: doc['number_of_pages_median'] ?? 0,
            language: doc['language']?.first ?? 'English',
            publishedDate: doc['first_publish_year'] != null
                ? DateTime(doc['first_publish_year'])
                : DateTime.now(),
          );
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('Error searching books: $e');
      return [];
    }
  }
  
  // Get book reading URL
  Future<String?> getBookReadingUrl(String bookId) async {
    try {
      // Try to get Internet Archive borrow link
      final response = await _dio.get(
        'https://openlibrary.org/works/$bookId.json',
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Check if book has Internet Archive ID
        if (data['ocaid'] != null) {
          return 'https://archive.org/details/${data['ocaid']}';
        }
      }
      
      // Fallback to Open Library reader
      return 'https://openlibrary.org/works/$bookId';
    } catch (e) {
      print('Error getting book URL: $e');
      return 'https://openlibrary.org/works/$bookId';
    }
  }
}
