import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timeline/data/database_helper.dart';
import 'package:timeline/models/note.dart';

void main() {
  late DatabaseHelper dbHelper;

  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    // ensure we start with a fresh db for each test or handle cleanup
    // ideally, we'd use inMemoryDatabasePath but DatabaseHelper is a singleton using a specific path
    // For testing, we might need a way to override the path or factory.
    // However, since DatabaseHelper uses getDatabasesPath(), ffi memory approach usually works 
    // if we can reset it. 
    // Given the singleton, we'll just clear the table before each test.
    
    // NOTE: DatabaseHelper uses `join(await getDatabasesPath(), 'timeline.db')`
    // With FFI, this creates a file in memory or local disk depending on config.
    // We should clear the table to be safe.
    final db = await dbHelper.database;
    await db.delete('notes');
  });

  tearDownAll(() async {
    final db = await dbHelper.database;
    await db.close();
  });

  group('DatabaseHelper', () {
    test('insertNote inserts a note', () async {
      final note = Note.create(text: 'Test Note');
      await dbHelper.insertNote(note);

      final fetched = await dbHelper.getNote(note.id);
      expect(fetched, isNotNull);
      expect(fetched!.text, equals('Test Note'));
      expect(fetched.id, equals(note.id));
    });

    test('updateNote updates an existing note', () async {
      final note = Note.create(text: 'Original Text');
      await dbHelper.insertNote(note);

      final updatedNote = note.copyWith(text: 'Updated Text');
      await dbHelper.updateNote(updatedNote);

      final fetched = await dbHelper.getNote(note.id);
      expect(fetched!.text, equals('Updated Text'));
    });

    test('deleteNote removes the note', () async {
      final note = Note.create(text: 'To Delete');
      await dbHelper.insertNote(note);

      await dbHelper.deleteNote(note.id);

      final fetched = await dbHelper.getNote(note.id);
      expect(fetched, isNull);
    });

    test('getAllNotes returns notes sorted by pinned then date', () async {
      final t0 = DateTime.now();
      final t1 = t0.add(const Duration(seconds: 1));
      final t2 = t0.add(const Duration(seconds: 2));

      final note1 = Note(
        id: 'id-1',
        text: 'Note 1',
        createdAt: t0,
        updatedAt: t0,
        isPinned: false,
      );

      final note2 = Note(
        id: 'id-2',
        text: 'Note 2',
        createdAt: t1,
        updatedAt: t1,
        isPinned: true,
      );

      final note3 = Note(
        id: 'id-3',
        text: 'Note 3',
        createdAt: t2,
        updatedAt: t2,
        isPinned: false,
      );

      await dbHelper.insertNote(note1);
      await dbHelper.insertNote(note2);
      await dbHelper.insertNote(note3);

      final notes = await dbHelper.getAllNotes();
      expect(notes.length, equals(3));
      
      // Expected order:
      // 1. Pinned note (note2)
      // 2. Newest unpinned (note3)
      // 3. Oldest unpinned (note1)
      
      expect(notes[0].id, equals('id-2'));
      expect(notes[1].id, equals('id-3'));
      expect(notes[2].id, equals('id-1'));
    });

    test('searchNotes filters by text', () async {
      await dbHelper.insertNote(Note.create(text: 'Apple pie'));
      await dbHelper.insertNote(Note.create(text: 'Banana bread'));
      await dbHelper.insertNote(Note.create(text: 'Apple cider'));

      final results = await dbHelper.searchNotes(searchText: 'Apple');
      expect(results.length, equals(2));
      expect(results.any((n) => n.text == 'Apple pie'), isTrue);
      expect(results.any((n) => n.text == 'Apple cider'), isTrue);
    });

    test('searchNotes filters by tags', () async {
      await dbHelper.insertNote(Note.create(text: 'Note 1', tags: ['work', 'urgent']));
      await dbHelper.insertNote(Note.create(text: 'Note 2', tags: ['home']));
      await dbHelper.insertNote(Note.create(text: 'Note 3', tags: ['work']));

      final results = await dbHelper.searchNotes(tags: ['work']);
      expect(results.length, equals(2));
      expect(results.any((n) => n.text == 'Note 1'), isTrue);
      expect(results.any((n) => n.text == 'Note 3'), isTrue);
    });

    test('getAllTags returns unique extracted tags', () async {
      final n1 = Note.create(text: '1', tags: ['a', 'b']);
      final n2 = Note.create(text: '2', tags: ['b', 'c']);
      final n3 = Note.create(text: '3', tags: []);
      
      await dbHelper.insertNote(n1);
      await dbHelper.insertNote(n2);
      await dbHelper.insertNote(n3);

      final allNotes = await dbHelper.getAllNotes();
      expect(allNotes.length, equals(3), reason: 'All 3 notes should be inserted');
      
      final tags = await dbHelper.getAllTags();
      expect(tags, containsAll(['a', 'b', 'c']));
      expect(tags.length, equals(3));
    });
  });
}
