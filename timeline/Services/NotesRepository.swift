import Foundation
import SwiftData
import UIKit

final class NotesRepository {
    private let context: ModelContext
    private let imageStore: ImageStore

    init(context: ModelContext, imageStore: ImageStore) {
        self.context = context
        self.imageStore = imageStore
    }

    func create(text: String, images: [UIImage], tagInput: [String]) throws -> Note {
        let paths = try imageStore.save(images: images)
        let tags = Tag.normalized(from: tagInput)
        let note = Note(text: text, imagePaths: paths, tags: tags)
        context.insert(note)
        try context.save()
        return note
    }

    func update(
        note: Note,
        text: String,
        images: [UIImage],
        removedPaths: [String],
        tagInput: [String],
        isPinned: Bool
    ) throws {
        let newPaths = try imageStore.save(images: images)
        note.text = text
        note.tags = Tag.normalized(from: tagInput)
        note.isPinned = isPinned
        note.imagePaths.append(contentsOf: newPaths)
        note.updatedAt = Date()
        try imageStore.delete(paths: removedPaths)
        try context.save()
    }

    func delete(note: Note) throws {
        try imageStore.delete(paths: note.imagePaths)
        context.delete(note)
        try context.save()
    }
}
