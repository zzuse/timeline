import AVFoundation
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
    @State private var recordedAudioPaths: [String] = []
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var pendingAudioPath: String?
    @State private var didSave = false
    @State private var isShowingCamera = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private let imageStore = ImageStore()
    private let audioStore = AudioStore()

    private var repository: NotesRepositoryType {
        if isSimulatingSaveFailure {
            return FailingNotesRepository()
        }
        return NotesRepository(context: modelContext, imageStore: imageStore, audioStore: audioStore)
    }

    private var isSimulatingSaveFailure: Bool {
        ProcessInfo.processInfo.arguments.contains("-simulateSaveFailure")
    }

    private var canSave: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !selectedImages.isEmpty || !recordedAudioPaths.isEmpty
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
                    Text("Audio")
                        .font(.headline)

                    if !recordedAudioPaths.isEmpty {
                        ForEach(Array(recordedAudioPaths.enumerated()), id: \.element) { index, path in
                            if let url = try? audioStore.url(for: path) {
                                AudioClipRow(
                                    title: "Recording \(index + 1)",
                                    url: url
                                ) {
                                    removeRecording(path)
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
        .onDisappear {
            if isRecording {
                stopRecording()
            }
            if !didSave {
                try? audioStore.delete(paths: recordedAudioPaths)
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
            _ = try repository.create(
                text: text,
                images: selectedImages,
                audioPaths: recordedAudioPaths,
                tagInput: tags
            )
            didSave = true
            dismiss()
        } catch {
            showError("Failed to save this note. Please try again.")
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
            recordedAudioPaths.append(path)
            pendingAudioPath = nil
        }
    }

    private func removeRecording(_ path: String) {
        recordedAudioPaths.removeAll { $0 == path }
        try? audioStore.delete(paths: [path])
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

    func create(text: String, images: [UIImage], audioPaths: [String], tagInput: [String]) throws -> Note {
        throw Failure.simulated
    }
}

#Preview {
    NavigationStack {
        ComposeView()
    }
}
