import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/collections_service.dart';
import '../../core/services/cache_service.dart';
import '../../data/models/article_collection.dart';
import '../../providers/auth_provider.dart';
import '../reader/reader_screen.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  late CollectionsService _collectionsService;
  List<ArticleCollection> _collections = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _initService();
  }
  
  Future<void> _initService() async {
    final cache = CacheService();
    final isar = await cache.getIsar();
    _collectionsService = CollectionsService(isar);
    _loadCollections();
  }
  
  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    final collections = await _collectionsService.getAllCollections();
    if (mounted) {
      setState(() {
        _collections = collections;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _collections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 80,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Collections Yet',
                        style: AppTextStyles.uiH2.copyWith(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create collections to organize articles',
                        style: AppTextStyles.uiBody.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Collection'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _collections.length,
                  itemBuilder: (context, index) {
                    final collection = _collections[index];
                    return _buildCollectionCard(collection);
                  },
                ),
    );
  }
  
  Widget _buildCollectionCard(ArticleCollection collection) {
    final color = _getColor(collection.color);
    
    return GestureDetector(
      onTap: () => _openCollection(collection),
      onLongPress: () => _showCollectionOptions(collection),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIcon(collection.icon),
                        color: color,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    if (collection.isPublic)
                      Icon(Icons.public, size: 16, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  collection.name,
                  style: AppTextStyles.uiBody.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (collection.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    collection.description!,
                    style: AppTextStyles.uiCaption.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.article, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${collection.articleCount} articles',
                      style: AppTextStyles.uiCaption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedColor = 'blue';
    String selectedIcon = 'folder';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Collection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Color', style: AppTextStyles.uiCaption),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['blue', 'green', 'orange', 'purple', 'red'].map((color) {
                    return ChoiceChip(
                      label: Text(color),
                      selected: selectedColor == color,
                      onSelected: (selected) {
                        if (selected) setState(() => selectedColor = color);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Icon', style: AppTextStyles.uiCaption),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['folder', 'book', 'star', 'favorite', 'work'].map((icon) {
                    return ChoiceChip(
                      label: Icon(_getIcon(icon), size: 20),
                      selected: selectedIcon == icon,
                      onSelected: (selected) {
                        if (selected) setState(() => selectedIcon = icon);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                
                final user = ref.read(authStateProvider).value;
                await _collectionsService.createCollection(
                  name: nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  ownerId: user?.uid,
                  color: selectedColor,
                  icon: selectedIcon,
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadCollections();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCollectionOptions(ArticleCollection collection) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(collection.isPublic ? Icons.lock : Icons.public),
            title: Text(collection.isPublic ? 'Make Private' : 'Make Public'),
            onTap: () async {
              Navigator.pop(context);
              await _collectionsService.togglePublic(collection.collectionId);
              _loadCollections();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await _collectionsService.deleteCollection(collection.collectionId);
              _loadCollections();
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _openCollection(ArticleCollection collection) async {
    final articles = await _collectionsService.getCollectionArticles(collection.collectionId);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    collection.name,
                    style: AppTextStyles.uiH2.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: articles.isEmpty
                  ? Center(
                      child: Text(
                        'No articles in this collection',
                        style: AppTextStyles.uiBody.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: articles.length,
                      itemBuilder: (context, index) {
                        final article = articles[index];
                        return ListTile(
                          title: Text(article.title),
                          subtitle: Text(
                            article.category,
                            style: AppTextStyles.uiCaption,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReaderScreen(article: article),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getColor(String? colorName) {
    switch (colorName) {
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'red': return Colors.red;
      default: return Colors.blue;
    }
  }
  
  IconData _getIcon(String? iconName) {
    switch (iconName) {
      case 'book': return Icons.book;
      case 'star': return Icons.star;
      case 'favorite': return Icons.favorite;
      case 'work': return Icons.work;
      default: return Icons.folder;
    }
  }
}
