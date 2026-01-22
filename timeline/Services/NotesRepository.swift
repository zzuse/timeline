import CryptoKit
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
    private let syncQueue: SyncQueue

    init(context: ModelContext, imageStore: ImageStore, audioStore: AudioStore, syncQueue: SyncQueue = try! SyncQueue()) {
        self.context = context
        self.imageStore = imageStore
        self.audioStore = audioStore
        self.syncQueue = syncQueue
    }

    func create(text: String, images: [UIImage], audioPaths: [String], tagInput: [String]) throws -> Note {
        let paths = try imageStore.save(images: images)
        let tags = Tag.normalized(from: tagInput)
        let note = Note(text: text, imagePaths: paths, audioPaths: audioPaths, tags: tags)
        context.insert(note)
        try context.save()
        try syncQueue.enqueueCreate(
            note: note,
            imagePaths: note.imagePaths,
            audioPaths: note.audioPaths,
            tags: note.tags.map(\.name)
        )
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
        try syncQueue.enqueueUpdate(
            note: note,
            imagePaths: newPaths,
            audioPaths: audioPaths,
            tags: note.tags.map(\.name)
        )
    }

    func delete(note: Note) throws {
        try syncQueue.enqueueDelete(note: note)
        try imageStore.delete(paths: note.imagePaths)
        try audioStore.delete(paths: note.audioPaths)
        context.delete(note)
        try context.save()
    }

    func enqueueFullResync() throws {
        let descriptor = FetchDescriptor<Note>()
        let notes = try context.fetch(descriptor)
        for note in notes {
            try syncQueue.enqueueUpdate(
                note: note,
                imagePaths: note.imagePaths,
                audioPaths: note.audioPaths,
                tags: note.tags.map(\.name)
            )
        }
    }

    func upsertNote(
        id: String,
        text: String,
        isPinned: Bool,
        tags: [String],
        createdAt: Date,
        updatedAt: Date,
        imagePaths: [String],
        audioPaths: [String]
    ) throws {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        let existing = try context.fetch(descriptor).first
        let note = existing ?? Note(
            text: text,
            imagePaths: imagePaths,
            audioPaths: audioPaths,
            tags: Tag.normalized(from: tags)
        )
        note.id = id
        note.text = text
        note.isPinned = isPinned
        note.tags = Tag.normalized(from: tags)
        note.createdAt = createdAt
        note.updatedAt = updatedAt
        note.imagePaths = imagePaths
        note.audioPaths = audioPaths
        if existing == nil {
            context.insert(note)
        }
        try context.save()
    }

    func saveRestoreMedia(noteId: String, media: [SyncMediaPayload]) throws -> (imagePaths: [String], audioPaths: [String]) {
        var imagePaths: [String] = []
        var audioPaths: [String] = []
        let imagesURL = documentsURL().appendingPathComponent("Images", isDirectory: true)
        let audioURL = documentsURL().appendingPathComponent("Audio", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: audioURL, withIntermediateDirectories: true)

        for item in media {
            guard let data = Data(base64Encoded: item.dataBase64) else {
                continue
            }
            let targetURL: URL
            let fileName: String
            if item.kind == "audio" {
                if let existing = try findExistingFile(matching: item.checksum, in: audioURL) {
                    audioPaths.append(existing)
                    continue
                }
                fileName = item.filename.isEmpty ? "\(UUID().uuidString).m4a" : item.filename
                targetURL = audioURL.appendingPathComponent(fileName)
                try data.write(to: targetURL, options: .atomic)
                audioPaths.append(fileName)
            } else {
                if let existing = try findExistingFile(matching: item.checksum, in: imagesURL) {
                    imagePaths.append(existing)
                    continue
                }
                let ext = item.filename.split(separator: ".").last.map(String.init)
                let resolvedExt = ext ?? (item.contentType.contains("png") ? "png" : "jpg")
                fileName = item.filename.isEmpty ? "\(UUID().uuidString).\(resolvedExt)" : item.filename
                targetURL = imagesURL.appendingPathComponent(fileName)
                try data.write(to: targetURL, options: .atomic)
                imagePaths.append(fileName)
            }
        }

        return (imagePaths, audioPaths)
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func findExistingFile(matching checksum: String, in directory: URL) throws -> String? {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files {
            let data = try Data(contentsOf: file)
            let digest = SHA256.hash(data: data)
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            if hash == checksum {
                return file.lastPathComponent
            }
        }
        return nil
    }
}
