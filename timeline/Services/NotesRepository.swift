import Foundation
import SwiftData
import UIKit

protocol NotesRepositoryType {
    func create(text: String, images: [UIImage], audioPaths: [String], tagInput: [String]) throws -> Note
}

final class NotesRepository: NotesRepositoryType {
    private let context: ModelContext
    private let imageStore: ImageStore
    private let audioStore: AudioStore

    init(context: ModelContext, imageStore: ImageStore, audioStore: AudioStore) {
        self.context = context
        self.imageStore = imageStore
        self.audioStore = audioStore
    }

    func create(text: String, images: [UIImage], audioPaths: [String], tagInput: [String]) throws -> Note {
        let paths = try imageStore.save(images: images)
        let tags = Tag.normalized(from: tagInput)
        let note = Note(text: text, imagePaths: paths, audioPaths: audioPaths, tags: tags)
        context.insert(note)
        try context.save()
        return note
    }

    func update(
        note: Note,
        text: String,
        images: [UIImage],
        removedPaths: [String],
        audioPaths: [String],
        removedAudioPaths: [String],
        tagInput: [String],
        isPinned: Bool
    ) throws {
        let newPaths = try imageStore.save(images: images)
        note.text = text
        note.tags = Tag.normalized(from: tagInput)
        note.isPinned = isPinned
        if !removedPaths.isEmpty {
            note.imagePaths.removeAll { removedPaths.contains($0) }
        }
        if !removedAudioPaths.isEmpty {
            note.audioPaths.removeAll { removedAudioPaths.contains($0) }
        }
        note.imagePaths.append(contentsOf: newPaths)
        note.audioPaths.append(contentsOf: audioPaths)
        note.updatedAt = Date()
        try imageStore.delete(paths: removedPaths)
        try audioStore.delete(paths: removedAudioPaths)
        try context.save()
    }

    func delete(note: Note) throws {
        try imageStore.delete(paths: note.imagePaths)
        try audioStore.delete(paths: note.audioPaths)
        context.delete(note)
        try context.save()
    }
}
