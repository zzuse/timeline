import SwiftData
import SwiftUI

struct TagInputView: View {
    @Binding var tags: [String]
    @State private var tagText = ""
    @Query(sort: \Tag.name) private var knownTags: [Tag]

    private var cleanedInput: String {
        tagText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var suggestions: [String] {
        guard !cleanedInput.isEmpty else { return [] }
        let current = Set(tags)
        return knownTags
            .map(\.name)
            .filter { $0.hasPrefix(cleanedInput) && !current.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
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
                        addTag(cleanedInput)
                    }

                Button {
                    addTag(cleanedInput)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(cleanedInput.isEmpty)
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

    private func addTag(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return }
        if !tags.contains(cleaned) {
            tags.append(cleaned)
        }
        tagText = ""
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

#Preview {
    TagInputView(tags: .constant(["work", "swiftui"]))
        .padding()
}
