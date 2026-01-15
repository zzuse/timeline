import SwiftData
import SwiftUI

struct SearchFilterView: View {
    @Binding var searchText: String
    @Binding var selectedTags: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var tagText = ""
    @Query(sort: \Tag.name) private var knownTags: [Tag]

    private var suggestions: [String] {
        guard let input = normalizeInput(tagText) else { return [] }
        let current = Set(selectedTags)
        return knownTags
            .map(\.name)
            .filter { $0.hasPrefix(input) && !current.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextField("Search notes", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Tags") {
                    if !selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text("#\(tag)")
                                            .font(.caption)
                                        Button {
                                            remove(tag)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Add tag", text: $tagText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                addTag(tagText)
                            }

                        Button {
                            addTag(tagText)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .disabled(normalizeInput(tagText) == nil)
                    }

                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button {
                                        addTag(suggestion)
                                    } label: {
                                        Text("#\(suggestion)")
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search & Filter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
                        searchText = ""
                        selectedTags = []
                        dismiss()
                    }
                }
            }
        }
    }

    private func addTag(_ value: String) {
        guard let cleaned = normalizeInput(value) else { return }
        if !selectedTags.contains(cleaned) {
            selectedTags.append(cleaned)
        }
        tagText = ""
    }

    private func remove(_ tag: String) {
        selectedTags.removeAll { $0 == tag }
    }

    private func normalizeInput(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let normalized = withoutHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}

#Preview {
    SearchFilterView(searchText: .constant("swift"), selectedTags: .constant(["work"]))
}
