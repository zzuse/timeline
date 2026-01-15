import Foundation
import SwiftData

@Model
final class Tag: Identifiable {
    @Attribute(.unique) var name: String

    init(name: String) {
        self.name = name
    }

    static func normalized(from input: [String]) -> [Tag] {
        let names = input
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let unique = Array(Set(names))
        return unique.map(Tag.init)
    }
}
