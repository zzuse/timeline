import Foundation
import SwiftData

@Model
final class Note: Identifiable {
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var imagePaths: [String]
    var tags: [Tag]

    init(text: String, imagePaths: [String], tags: [Tag]) {
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.imagePaths = imagePaths
        self.tags = tags
    }
}
