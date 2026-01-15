import Foundation

struct TimelineFilter {
    let query: String
    let requiredTags: Set<String>

    static func text(_ value: String) -> TimelineFilter {
        TimelineFilter(query: value, requiredTags: [])
    }

    static func search(text: String, tags: [String]) -> TimelineFilter {
        TimelineFilter(
            query: text,
            requiredTags: Set(tags.compactMap(Self.normalizeTag))
        )
    }

    func apply(to notes: [Note]) -> [Note] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = trimmedQuery.lowercased()

        return notes.filter { note in
            let matchesText: Bool
            if normalizedQuery.isEmpty {
                matchesText = true
            } else {
                matchesText = note.text.lowercased().contains(normalizedQuery)
            }

            let matchesTags: Bool
            if requiredTags.isEmpty {
                matchesTags = true
            } else {
                let noteTags = Set(note.tags.compactMap { Self.normalizeTag($0.name) })
                matchesTags = requiredTags.isSubset(of: noteTags)
            }

            return matchesText && matchesTags
        }
    }

    private static func normalizeTag(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let normalized = withoutHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}
