import Foundation
import SwiftData

@Model
final class Note: Identifiable {
    var id: String
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var imagePaths: [String]
    var audioPaths: [String]
    var tags: [Tag]

    init(text: String, imagePaths: [String], audioPaths: [String] = [], tags: [Tag]) {
        self.id = UUID().uuidString
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.imagePaths = imagePaths
        self.audioPaths = audioPaths
        self.tags = tags
    }
}
