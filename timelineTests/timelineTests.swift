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
        let repo = NotesRepository(context: context, imageStore: ImageStore())

        let note = try repo.create(text: "Hi", images: [], tagInput: ["Swift", "swift"])
        #expect(note.tags.count == 1)
        #expect(note.updatedAt >= note.createdAt)
    }
}
