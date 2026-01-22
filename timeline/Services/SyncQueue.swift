import CryptoKit
import Foundation

enum SyncOpType: String, Codable {
    case create
    case update
    case delete
}

struct SyncQueuedNote: Codable {
    let id: String
    let text: String
    let isPinned: Bool
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
}

struct SyncQueuedMedia: Codable {
    let id: String
    let noteId: String
    let kind: String
    let filename: String
    let contentType: String
    let checksum: String
    let localPath: String
}

struct SyncQueueItem: Codable {
    let opId: String
    let opType: SyncOpType
    let note: SyncQueuedNote
    let media: [SyncQueuedMedia]
}

final class SyncQueue {
    private let baseURL: URL
    private let mediaURL: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL? = nil) throws {
        let root = baseURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.baseURL = root.appendingPathComponent("SyncQueue", isDirectory: true)
        self.mediaURL = self.baseURL.appendingPathComponent("Media", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(at: self.mediaURL, withIntermediateDirectories: true)
    }

    func enqueueCreate(note: Note, imagePaths: [String], audioPaths: [String], tags: [String]) throws {
        try enqueue(note: note, imagePaths: imagePaths, audioPaths: audioPaths, tags: tags, opType: .create, deletedAt: nil)
    }

    func enqueueUpdate(note: Note, imagePaths: [String], audioPaths: [String], tags: [String]) throws {
        try enqueue(note: note, imagePaths: imagePaths, audioPaths: audioPaths, tags: tags, opType: .update, deletedAt: nil)
    }

    func enqueueDelete(note: Note) throws {
        let deletedAt = Date()
        try enqueue(
            note: note,
            imagePaths: note.imagePaths,
            audioPaths: note.audioPaths,
            tags: note.tags.map(\.name),
            opType: .delete,
            deletedAt: deletedAt
        )
    }

    func pending() throws -> [SyncQueueItem] {
        let files = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { file in
            let data = try Data(contentsOf: file)
            return try decoder.decode(SyncQueueItem.self, from: data)
        }
    }

    func pendingCount() throws -> Int {
        try pending().count
    }

    func remove(items: [SyncQueueItem]) throws {
        let files = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        for item in items {
            let matches = files.filter { $0.lastPathComponent.contains(item.opId) }
            for url in matches {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func enqueue(
        note: Note,
        imagePaths: [String],
        audioPaths: [String],
        tags: [String],
        opType: SyncOpType,
        deletedAt: Date?
    ) throws {
        let opId = UUID().uuidString
        let queuedNote = SyncQueuedNote(
            id: note.id,
            text: note.text,
            isPinned: note.isPinned,
            tags: tags,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            deletedAt: deletedAt
        )
        let media = try copyMedia(noteId: note.id, imagePaths: imagePaths, audioPaths: audioPaths)
        let item = SyncQueueItem(opId: opId, opType: opType, note: queuedNote, media: media)
        let data = try encoder.encode(item)
        try data.write(to: baseURL.appendingPathComponent(fileName(for: opId)), options: .atomic)
    }

    private func fileName(for opId: String) -> String {
        let stamp = Int(Date().timeIntervalSince1970)
        return "op_\(stamp)_\(opId).json"
    }

    private func copyMedia(noteId: String, imagePaths: [String], audioPaths: [String]) throws -> [SyncQueuedMedia] {
        var queued: [SyncQueuedMedia] = []
        let imageStore = ImageStore()
        let audioStore = AudioStore()
        for path in imagePaths {
            let url = try imageStore.url(for: path)
            let id = UUID().uuidString
            let filename = "\(id).jpg"
            let dest = mediaURL.appendingPathComponent(filename)
            try fileManager.copyItem(at: url, to: dest)
            let checksum = try sha256(for: dest)
            queued.append(SyncQueuedMedia(
                id: id,
                noteId: noteId,
                kind: "image",
                filename: filename,
                contentType: "image/jpeg",
                checksum: checksum,
                localPath: dest.lastPathComponent
            ))
        }
        for path in audioPaths {
            let url = try audioStore.url(for: path)
            let id = UUID().uuidString
            let filename = "\(id).m4a"
            let dest = mediaURL.appendingPathComponent(filename)
            try fileManager.copyItem(at: url, to: dest)
            let checksum = try sha256(for: dest)
            queued.append(SyncQueuedMedia(
                id: id,
                noteId: noteId,
                kind: "audio",
                filename: filename,
                contentType: "audio/m4a",
                checksum: checksum,
                localPath: dest.lastPathComponent
            ))
        }
        return queued
    }

    private func sha256(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
