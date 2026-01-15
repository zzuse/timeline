import SwiftData
import SwiftUI

struct TimelineView: View {
    @Query private var notes: [Note]

    private var sortedNotes: [Note] {
        NoteSorter.sort(notes)
    }

    private var pinnedNotes: [Note] {
        sortedNotes.filter { $0.isPinned }
    }

    private var regularNotes: [Note] {
        sortedNotes.filter { !$0.isPinned }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                ContentUnavailableView(
                    "No Notes Yet",
                    systemImage: "square.and.pencil",
                    description: Text("Create your first note to start the timeline.")
                )
            } else {
                List {
                    if !pinnedNotes.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedNotes, id: \.persistentModelID) { note in
                                NoteRow(note: note)
                            }
                        }
                    }

                    Section("All") {
                        ForEach(regularNotes, id: \.persistentModelID) { note in
                            NoteRow(note: note)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Timeline")
    }
}

#Preview {
    TimelineView()
}
