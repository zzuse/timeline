//
//  timelineApp.swift
//  timeline
//
//  Created by zhen zhang on 2026-01-14.
//

import SwiftData
import SwiftUI

@main
struct timelineApp: App {
    private var modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Note.self, Tag.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
