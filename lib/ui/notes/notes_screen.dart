import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/notes_service.dart';
import '../../data/models/note.dart';
import 'note_editor_screen.dart';
import 'package:intl/intl.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NotesService _notesService = NotesService();
  final TextEditingController _searchController = TextEditingController();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadNotes();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await _notesService.getAllNotes();
    setState(() {
      _notes = notes;
      _filteredNotes = notes;
      _isLoading = false;
    });
  }
  
  void _searchNotes(String query) async {
    if (query.isEmpty) {
      setState(() => _filteredNotes = _notes);
    } else {
      final results = await _notesService.searchNotes(query);
      setState(() => _filteredNotes = results);
    }
  }
  
  Future<void> _deleteNote(Note note) async {
    await _notesService.deleteNote(note.id);
    _loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted')),
      );
    }
  }
  
  Future<void> _togglePin(Note note) async {
    await _notesService.togglePin(note.id);
    _loadNotes();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NoteEditorScreen(),
                ),
              );
              _loadNotes();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchNotes('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: _searchNotes,
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.note_outlined, size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text('No notes yet', style: AppTextStyles.uiH2),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to create your first note',
                              style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = _filteredNotes[index];
                          return _buildNoteCard(note);
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoteCard(Note note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(note: note),
            ),
          );
          _loadNotes();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                    ),
                  Expanded(
                    child: Text(
                      note.title,
                      style: AppTextStyles.uiH3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                            const SizedBox(width: 8),
                            Text(note.isPinned ? 'Unpin' : 'Pin'),
                          ],
                        ),
                        onTap: () => _togglePin(note),
                      ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.warning)),
                          ],
                        ),
                        onTap: () => _deleteNote(note),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (note.articleTitle != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          note.articleTitle!,
                          style: AppTextStyles.uiCaption.copyWith(color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(note.updatedAt),
                style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
