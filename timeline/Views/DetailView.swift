import SwiftUI
import UIKit

struct DetailView: View {
    let note: Note

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var loadedImages: [UIImage] = []
    @State private var isShowingEdit = false
    @State private var isShowingDelete = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private let imageStore = ImageStore()

    private var repository: NotesRepository {
        NotesRepository(context: modelContext, imageStore: imageStore)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !loadedImages.isEmpty {
                    ImageGrid(images: loadedImages)
                }

                if !note.text.isEmpty {
                    Text(note.text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                VStack(alignment: .leading, spacing: 4) {
                    Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Updated \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Note")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    togglePin()
                } label: {
                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: "pin")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isShowingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            loadImages()
        }
        .sheet(isPresented: $isShowingEdit) {
            NavigationStack {
                EditView(note: note)
            }
        }
        .alert("Delete Note?", isPresented: $isShowingDelete) {
            Button("Delete", role: .destructive) {
                deleteNote()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Something went wrong", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func loadImages() {
        loadedImages = note.imagePaths.compactMap { path in
            try? imageStore.load(path: path)
        }
    }

    private func togglePin() {
        note.isPinned.toggle()
        note.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            showError("Unable to update pin status.")
        }
    }

    private func deleteNote() {
        do {
            try repository.delete(note: note)
            dismiss()
        } catch {
            showError("Unable to delete this note.")
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}

#Preview {
    let note = Note(text: "Sample note", imagePaths: [], tags: [Tag(name: "swift")])
    return NavigationStack {
        DetailView(note: note)
    }
}
