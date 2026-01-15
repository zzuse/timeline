//
//  timelineTests.swift
//  timelineTests
//
//  Created by zhen zhang on 2026-01-14.
//

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
}
