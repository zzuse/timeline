import SwiftUI

struct NoteRow: View {
    let note: Note
    private let imageStore = ImageStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let path = note.imagePaths.first,
               let uiImage = try? imageStore.load(path: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(8)
            }

            if !note.text.isEmpty {
                Text(note.text)
                    .font(.body)
                    .lineLimit(3)
            }

            if !note.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(note.tags, id: \.name) { tag in
                        Text("#\(tag.name)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }

            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    let note = Note(text: "Hello from preview", imagePaths: [], tags: [Tag(name: "swift")])
    return NoteRow(note: note)
        .padding()
}
