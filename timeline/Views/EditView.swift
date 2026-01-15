import PhotosUI
import SwiftUI
import UIKit

struct EditView: View {
    private struct StoredImage: Identifiable {
        let id = UUID()
        let path: String
        let image: UIImage
    }

    let note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text: String
    @State private var tags: [String]
    @State private var isPinned: Bool
    @State private var existingImages: [StoredImage] = []
    @State private var newImages: [UIImage] = []
    @State private var removedPaths: [String] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private let imageStore = ImageStore()

    init(note: Note) {
        self.note = note
        _text = State(initialValue: note.text)
        _tags = State(initialValue: note.tags.map(\.name))
        _isPinned = State(initialValue: note.isPinned)
    }

    private var repository: NotesRepository {
        NotesRepository(context: modelContext, imageStore: imageStore)
    }

    private var hasContent: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !existingImages.isEmpty || !newImages.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.headline)
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(uiColor: .separator))
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Photos")
                        .font(.headline)

                    if !existingImages.isEmpty {
                        Text("Saved")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ImageGrid(images: existingImages.map(\.image)) { index in
                            let removed = existingImages.remove(at: index)
                            removedPaths.append(removed.path)
                        }
                    }

                    if !newImages.isEmpty {
                        Text("New")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ImageGrid(images: newImages) { index in
                            newImages.remove(at: index)
                        }
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: 8,
                            matching: .images
                        ) {
                            Label("Photos", systemImage: "photo.on.rectangle")
                        }

                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                isShowingCamera = true
                            } else {
                                showError("Camera is not available on this device.")
                            }
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                    TagInputView(tags: $tags)
                }

                Toggle("Pinned", isOn: $isPinned)
            }
            .padding()
        }
        .navigationTitle("Edit Note")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(!hasContent)
            }
        }
        .onAppear {
            loadExistingImagesIfNeeded()
        }
        .onChange(of: photoItems) { items in
            appendPhotos(from: items)
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker(isPresented: $isShowingCamera) { image in
                newImages.append(image)
            }
        }
        .alert("Unable to Save", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func loadExistingImagesIfNeeded() {
        guard existingImages.isEmpty else { return }
        var loaded: [StoredImage] = []
        for path in note.imagePaths {
            if let image = try? imageStore.load(path: path) {
                loaded.append(StoredImage(path: path, image: image))
            }
        }
        existingImages = loaded
    }

    private func appendPhotos(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        newImages.append(image)
                    }
                }
            }
            await MainActor.run {
                photoItems = []
            }
        }
    }

    private func save() {
        do {
            try repository.update(
                note: note,
                text: text,
                images: newImages,
                removedPaths: removedPaths,
                tagInput: tags,
                isPinned: isPinned
            )
            dismiss()
        } catch {
            showError("Failed to update this note. Please try again.")
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}

#Preview {
    let sample = Note(text: "Sample", imagePaths: [], tags: [Tag(name: "draft")])
    return NavigationStack {
        EditView(note: sample)
    }
}
