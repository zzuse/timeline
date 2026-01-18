import AVFoundation
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
    @State private var existingAudioPaths: [String] = []
    @State private var newAudioPaths: [String] = []
    @State private var removedAudioPaths: [String] = []
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var pendingAudioPath: String?
    @State private var didSave = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private let imageStore = ImageStore()
    private let audioStore = AudioStore()
    private let syncQueue = try! SyncQueue()

    init(note: Note) {
        self.note = note
        _text = State(initialValue: note.text)
        _tags = State(initialValue: note.tags.map(\.name))
        _isPinned = State(initialValue: note.isPinned)
        _existingAudioPaths = State(initialValue: note.audioPaths)
    }

    private var repository: NotesRepository {
        NotesRepository(context: modelContext, imageStore: imageStore, audioStore: audioStore, syncQueue: syncQueue)
    }

    private var hasContent: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !existingImages.isEmpty || !newImages.isEmpty || !existingAudioPaths.isEmpty || !newAudioPaths.isEmpty
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
                    Text("Audio")
                        .font(.headline)

                    if !existingAudioPaths.isEmpty {
                        Text("Saved")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(Array(existingAudioPaths.enumerated()), id: \.element) { index, path in
                            if let url = try? audioStore.url(for: path) {
                                AudioClipRow(
                                    title: "Recording \(index + 1)",
                                    url: url
                                ) {
                                    removeExistingRecording(path)
                                }
                            }
                        }
                    }

                    if !newAudioPaths.isEmpty {
                        Text("New")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(Array(newAudioPaths.enumerated()), id: \.element) { index, path in
                            if let url = try? audioStore.url(for: path) {
                                AudioClipRow(
                                    title: "New Recording \(index + 1)",
                                    url: url
                                ) {
                                    removeNewRecording(path)
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            toggleRecording()
                        } label: {
                            Label(
                                isRecording ? "Stop Recording" : "Record",
                                systemImage: isRecording ? "stop.circle.fill" : "mic.circle"
                            )
                        }

                        if isRecording {
                            Text("Recording...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
        .onDisappear {
            if isRecording {
                stopRecording()
            }
            if !didSave {
                try? audioStore.delete(paths: newAudioPaths)
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
                audioPaths: newAudioPaths,
                removedAudioPaths: removedAudioPaths,
                tagInput: tags,
                isPinned: isPinned
            )
            didSave = true
            dismiss()
        } catch {
            showError("Failed to update this note. Please try again.")
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission { allowed in
            DispatchQueue.main.async {
                guard allowed else {
                    showError("Microphone access is required to record audio.")
                    return
                }
                do {
                    try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    let recording = audioStore.makeRecordingURL()
                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 12000,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    let recorder = try AVAudioRecorder(url: recording.url, settings: settings)
                    recorder.prepareToRecord()
                    recorder.record()
                    audioRecorder = recorder
                    pendingAudioPath = recording.filename
                    isRecording = true
                } catch {
                    showError("Unable to start recording. Please try again.")
                }
            }
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        if let path = pendingAudioPath {
            newAudioPaths.append(path)
            pendingAudioPath = nil
        }
    }

    private func removeExistingRecording(_ path: String) {
        existingAudioPaths.removeAll { $0 == path }
        removedAudioPaths.append(path)
    }

    private func removeNewRecording(_ path: String) {
        newAudioPaths.removeAll { $0 == path }
        try? audioStore.delete(paths: [path])
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
