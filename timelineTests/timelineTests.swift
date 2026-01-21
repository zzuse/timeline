//
//  timelineTests.swift
//  timelineTests
//
//  Created by zhen zhang on 2026-01-14.
//

import SwiftData
import Testing
import UIKit
@testable import timeline

struct timelineTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func tagNormalization() async throws {
        let tags = Tag.normalized(from: ["  Swift ", "swift", "iOS "])
        let names = tags.map { $0.name }.sorted()
        #expect(names == ["ios", "swift"])
    }

    @Test func noteDefaults() async throws {
        let note = Note(text: "Hello", imagePaths: [], tags: [])
        #expect(note.isPinned == false)
        #expect(note.createdAt <= note.updatedAt)
    }

    @Test func noteHasStableId() async throws {
        let note = Note(text: "Hello", imagePaths: [], tags: [])
        #expect(note.id.isEmpty == false)
    }

    @Test func imageStoreSaveLoadDelete() async throws {
        let store = ImageStore()
        let image = UIImage(systemName: "star")!

        let paths = try store.save(images: [image])
        #expect(paths.count == 1)

        let loaded = try store.load(path: paths[0])
        #expect(loaded.size != .zero)

        try store.delete(paths: paths)
        #expect(throws: ImageStore.ImageStoreError.missingFile) {
            _ = try store.load(path: paths[0])
        }
    }

    @Test func repositoryCreateUpdatesTimestamps() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
        let context = ModelContext(container)
        let repo = NotesRepository(context: context, imageStore: ImageStore(), audioStore: AudioStore())

        let note = try repo.create(text: "Hi", images: [], audioPaths: [], tagInput: ["Swift", "swift"])
        #expect(note.tags.count == 1)
        #expect(note.updatedAt >= note.createdAt)
    }

    @Test func repositoryEnqueuesCreate() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
        let context = ModelContext(container)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let repo = NotesRepository(context: context, imageStore: ImageStore(), audioStore: AudioStore(), syncQueue: queue)

        _ = try repo.create(text: "Hi", images: [], audioPaths: [], tagInput: [])

        #expect((try queue.pending()).count == 1)
    }

    @Test func repositoryUpdateDoesNotRequeueExistingMedia() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
        let context = ModelContext(container)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let repo = NotesRepository(context: context, imageStore: ImageStore(), audioStore: AudioStore(), syncQueue: queue)
        let imagesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        let filename = "test-image-\(UUID().uuidString).jpg"
        let fileURL = imagesURL.appendingPathComponent(filename)
        try Data("img".utf8).write(to: fileURL, options: .atomic)

        let note = Note(text: "Hello", imagePaths: [filename], tags: [])
        context.insert(note)
        try context.save()

        try repo.update(
            note: note,
            text: "Hello updated",
            images: [],
            removedPaths: [],
            audioPaths: [],
            removedAudioPaths: [],
            tagInput: [],
            isPinned: false
        )

        let items = try queue.pending().filter { $0.opType == .update }
        #expect(items.count == 1)
        #expect(items[0].media.isEmpty)
    }

    @Test func noteSorterPinnedFirst() async throws {
        let pinned = Note(text: "Pinned", imagePaths: [], tags: [])
        pinned.isPinned = true
        pinned.createdAt = Date(timeIntervalSince1970: 1)

        let newer = Note(text: "Newer", imagePaths: [], tags: [])
        newer.createdAt = Date(timeIntervalSince1970: 100)

        let older = Note(text: "Older", imagePaths: [], tags: [])
        older.createdAt = Date(timeIntervalSince1970: 10)

        let sorted = NoteSorter.sort([newer, older, pinned])
        #expect(sorted.first?.isPinned == true)
        #expect(sorted.dropFirst().map { $0.createdAt } == [newer.createdAt, older.createdAt])
    }

    @Test func textFilterMatchesCaseInsensitive() async throws {
        let notes = [
            Note(text: "Hello Swift", imagePaths: [], tags: []),
            Note(text: "Photo", imagePaths: [], tags: [])
        ]

        let filtered = TimelineFilter.text("swift").apply(to: notes)

        #expect(filtered.count == 1)
        #expect(filtered.first?.text == "Hello Swift")
    }

    @Test func tagFilterStripsHashPrefix() async throws {
        let note = Note(text: "Tagged", imagePaths: [], tags: [Tag(name: "swift")])

        let filtered = TimelineFilter.search(text: "", tags: ["#swift"]).apply(to: [note])

        #expect(filtered.count == 1)
    }
}
