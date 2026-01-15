import PhotosUI
import SwiftUI
import UIKit

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var tags: [String] = []
    @State private var selectedImages: [UIImage] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private let imageStore = ImageStore()

    private var repository: NotesRepositoryType {
        if isSimulatingSaveFailure {
            return FailingNotesRepository()
        }
        return NotesRepository(context: modelContext, imageStore: imageStore)
    }

    private var isSimulatingSaveFailure: Bool {
        ProcessInfo.processInfo.arguments.contains("-simulateSaveFailure")
    }

    private var canSave: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !selectedImages.isEmpty
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

                    if !selectedImages.isEmpty {
                        ImageGrid(images: selectedImages) { index in
                            selectedImages.remove(at: index)
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
            }
            .padding()
        }
        .navigationTitle("New Note")
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
                .disabled(!canSave)
            }
        }
        .onChange(of: photoItems) { items in
            appendPhotos(from: items)
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker(isPresented: $isShowingCamera) { image in
                selectedImages.append(image)
            }
        }
        .alert("Unable to Save", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func appendPhotos(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImages.append(image)
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
            _ = try repository.create(text: text, images: selectedImages, tagInput: tags)
            dismiss()
        } catch {
            showError("Failed to save this note. Please try again.")
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}

private struct FailingNotesRepository: NotesRepositoryType {
    enum Failure: Error {
        case simulated
    }

    func create(text: String, images: [UIImage], tagInput: [String]) throws -> Note {
        throw Failure.simulated
    }
}

#Preview {
    NavigationStack {
        ComposeView()
    }
}
