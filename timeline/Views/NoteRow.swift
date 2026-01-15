import AVFoundation
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

            if !note.audioPaths.isEmpty {
                Label("\(note.audioPaths.count) audio clip\(note.audioPaths.count == 1 ? "" : "s")", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

struct AudioClipRow: View {
    let title: String
    let url: URL
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: "waveform")
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            AudioPlaybackButton(url: url)
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AudioPlaybackButton: View {
    private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            onFinish()
        }
    }

    let url: URL

    @State private var player: AVAudioPlayer?
    @State private var delegate: PlaybackDelegate?
    @State private var isPlaying = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        Button {
            togglePlayback()
        } label: {
            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                .font(.title2)
        }
        .buttonStyle(.borderless)
        .alert("Unable to Play", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.stop()
            player = nil
            isPlaying = false
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let player = try AVAudioPlayer(contentsOf: url)
            let delegate = PlaybackDelegate {
                DispatchQueue.main.async {
                    isPlaying = false
                    self.player = nil
                    self.delegate = nil
                }
            }
            player.delegate = delegate
            player.play()
            self.player = player
            self.delegate = delegate
            isPlaying = true
        } catch {
            errorMessage = "Unable to play this recording."
            isShowingError = true
        }
    }
}
