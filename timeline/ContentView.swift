//
//  ContentView.swift
//  timeline
//
//  Created by zhen zhang on 2026-01-14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var syncState = NotesyncUIState()

    var body: some View {
        NavigationStack {
            TimelineView()
        }
        .environmentObject(syncState)
    }
}

#Preview {
    ContentView()
}
