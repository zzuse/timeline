//
//  ContentView.swift
//  timeline
//
//  Created by zhen zhang on 2026-01-14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var syncState = NotesyncUIState()
    @StateObject private var authSession = AuthSessionManager()

    var body: some View {
        NavigationStack {
            TimelineView()
        }
        .environmentObject(syncState)
        .environmentObject(authSession)
        .onOpenURL { url in
            Task { await authSession.handleCallback(url: url) }
        }
    }
}

#Preview {
    ContentView()
}
