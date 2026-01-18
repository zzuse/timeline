import Foundation

struct SyncNotePayload: Codable {
    let id: String
    let text: String
    let isPinned: Bool
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
}

struct SyncMediaPayload: Codable {
    let id: String
    let noteId: String
    let kind: String
    let filename: String
    let contentType: String
    let checksum: String
    let dataBase64: String
}

struct SyncOperationPayload: Codable {
    let opId: String
    let opType: String
    let note: SyncNotePayload
    let media: [SyncMediaPayload]
}

struct SyncRequest: Codable {
    let ops: [SyncOperationPayload]
}

struct SyncNoteResult: Codable {
    let noteId: String
    let result: String
    let note: SyncNotePayload
}

struct SyncResponse: Codable {
    let results: [SyncNoteResult]
}
