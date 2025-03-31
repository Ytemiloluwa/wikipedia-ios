import Foundation
import AppIntents

// This file serves as a central registry for all App Intents in the Wikipedia app.
// It helps ensure that all intent files are properly included in the build.

/// All app intents available in the Wikipedia iOS app
@available(iOS 16.0, *)
enum WikipediaIntents {
    // Register new intents here as they are added
    static var searchIntent: WikipediaSearchIntent {
        return WikipediaSearchIntent()
    }
    
    // Helper method to directly trigger a search
    static func search(for term: String) {
        Task {
            try? await searchIntent.perform()
        }
    }
} 