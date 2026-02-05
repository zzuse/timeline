import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note.dart';

/// Database helper for SQLite operations
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('timeline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Incremented for sync columns
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isPinned INTEGER NOT NULL DEFAULT 0,
        imagePaths TEXT,
        audioPaths TEXT,
        tags TEXT,
        serverId TEXT,
        lastSyncedAt INTEGER,
        isDirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Index for faster sorting by pinned status and date
    await db.execute(
      'CREATE INDEX idx_notes_pinned_created ON notes(isPinned DESC, createdAt DESC)'
    );
    
    // Index for sync operations
    await db.execute(
      'CREATE INDEX idx_notes_dirty ON notes(isDirty)'
    );
  }
  
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration v1 → v2: Add sync columns
      await db.execute('ALTER TABLE notes ADD COLUMN serverId TEXT');
      await db.execute('ALTER TABLE notes ADD COLUMN lastSyncedAt INTEGER');
      await db.execute('ALTER TABLE notes ADD COLUMN isDirty INTEGER NOT NULL DEFAULT 1');
      
      // Add index for sync operations
      await db.execute(
        'CREATE INDEX idx_notes_dirty ON notes(isDirty)'
      );
    }
  }

  // CRUD Operations

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Note?> getNote(String id) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final result = await db.query(
      'notes',
      orderBy: 'isPinned DESC, createdAt DESC',
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> searchNotes({String? searchText, List<String>? tags}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchText != null && searchText.isNotEmpty) {
      whereClause = 'text LIKE ?';
      whereArgs.add('%$searchText%');
    }

    if (tags != null && tags.isNotEmpty) {
      for (final tag in tags) {
        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += 'tags LIKE ?';
        whereArgs.add('%$tag%');
      }
    }

    final result = await db.query(
      'notes',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'isPinned DESC, createdAt DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<String>> getAllTags() async {
    final db = await database;
    final result = await db.query('notes', columns: ['tags']);
    
    final Set<String> allTags = {};
    for (final row in result) {
      final tagsStr = row['tags'] as String?;
      if (tagsStr != null && tagsStr.isNotEmpty) {
        allTags.addAll(tagsStr.split('|').where((t) => t.isNotEmpty));
      }
    }
    
    return allTags.toList()..sort();
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
