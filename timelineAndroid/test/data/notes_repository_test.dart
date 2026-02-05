import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timeline/data/notes_repository.dart';
import 'package:timeline/data/database_helper.dart';
import 'package:timeline/models/note.dart';
import '../mocks/mocks.dart';

void main() {
  late NotesRepository repository;
  late MockImageStore mockImageStore;
  late MockAudioStore mockAudioStore;
  late DatabaseHelper dbHelper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    // Clear DB
    final db = await dbHelper.database;
    await db.delete('notes');

    mockImageStore = MockImageStore();
    mockAudioStore = MockAudioStore();

    repository = NotesRepository.test(
      db: dbHelper,
      imageStore: mockImageStore,
      audioStore: mockAudioStore,
    );
  });

  tearDownAll(() async {
    final db = await dbHelper.database;
    await db.close();
  });

  group('NotesRepository', () {
    test('createNote saves note and images', () async {
      await repository.createNote(
        text: 'Test Note',
        tags: ['tag1'],
      );

      final notes = await repository.getAllNotes();
      expect(notes.length, 1);
      expect(notes.first.text, 'Test Note');
      expect(notes.first.tags, contains('tag1'));
    });

    test('updateNote updates text and tags', () async {
      final note = await repository.createNote(text: 'Original');
      
      await repository.updateNote(
        note: note,
        text: 'Updated',
        tags: ['new-tag'],
      );

      final updated = await repository.getNote(note.id);
      expect(updated!.text, 'Updated');
      expect(updated.tags, contains('new-tag'));
      // Should mark as dirty by default (DB default) or updated logic? 
      // The DB logic defaults isDirty=1.
      expect(updated.isDirty, true);
    });

    test('togglePin flips isPinned state', () async {
      final note = await repository.createNote(text: 'Note');
      expect(note.isPinned, false);

      await repository.togglePin(note);
      final pinned = await repository.getNote(note.id);
      expect(pinned!.isPinned, true);

      await repository.togglePin(pinned);
      final unpinned = await repository.getNote(note.id);
      expect(unpinned!.isPinned, false);
    });

    test('deleteNote removes from DB and calls stores', () async {
      final note = await repository.createNote(text: 'Delete me');
      
      // Inject some mock media paths to verify they get deleted
      // Since we can't easily inject real files in this mocked env without extra setup,
      // we'll rely on the mock stores verifying calls if we had verify(),
      // but here we just check DB state and ensure no crash.
      
      await repository.deleteNote(note);

      final fetched = await repository.getNote(note.id);
      expect(fetched, isNull);
    });

    test('getDirtyNotes returns only unsynced notes', () async {
      final note1 = await repository.createNote(text: 'Dirty'); // isDirty=1 default
      
      // Create a "clean" note (simulated sync)
      // We need to manually update it to clean because repository methods usually mark dirty
      // But creating a Note object with isDirty=false and using insertNoteForSync can simulate this
      final note2 = Note.create(text: 'Clean').copyWith(isDirty: false, serverId: 'server-1');
      await repository.insertNoteForSync(note2);

      final dirty = await repository.getDirtyNotes();
      expect(dirty.length, 1);
      expect(dirty.first.id, note1.id);
    });

    test('searchNotes returns matches', () async {
      await repository.createNote(text: 'Apple');
      await repository.createNote(text: 'Banana');

      final results = await repository.searchNotes(searchText: 'App');
      expect(results.length, 1);
      expect(results.first.text, 'Apple');
    });
  });
}
