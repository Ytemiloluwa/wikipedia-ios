import AppIntents
import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct WikipediaSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Wikipedia"
    static var description = IntentDescription("Search for an article on Wikipedia")
    
    @Parameter(title: "Search Term", requestValueDialog: IntentDialog("What would you like to search for?"))
    var searchTerm: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search Wikipedia for \(\.$searchTerm)")
    }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Search Wikipedia")
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Search Wikipedia",
            subtitle: "Search for \"\(searchTerm)\"",
            image: .init(systemName: "magnifyingglass")
        )
    }
    
    init() {
        self.searchTerm = ""
    }
    
    init(searchTerm: String) {
        self.searchTerm = searchTerm
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ShowsSnippetView {
        print("WikipediaSearchIntent: Performing search for \"\(searchTerm)\"")
        
        // Return the result with a snippet view
        return .result(value: searchTerm) {
            SearchSnippetView(searchTerm: searchTerm)
        }
    }
}

// Add a snippet view to show in the dynamic island / widget
@available(iOS 16.0, *)
struct SearchSnippetView: View {
    var searchTerm: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Wikipedia")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Search results for \"\(searchTerm)\"")
                    .font(.subheadline)
                    .bold()
            }
            
            Spacer()
            
            Button(action: {
                openWikipediaSearch(for: searchTerm)
            }) {
                Text("Open in Wikipedia")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    // This is the key function that correctly handles the search
    private func openWikipediaSearch(for term: String) {
        // Encode search term for URL
        let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Create unique ID for this search
        let uniqueID = UUID().uuidString
        
        // Create a URL with the format that SceneDelegate expects
        // From the codebase analysis, the correct URL format is:
        // wikipedia://search?term=[search term]
        let url = URL(string: "wikipedia://search?term=\(encodedTerm)&uid=\(uniqueID)")!
        
        print("Opening search URL: \(url.absoluteString)")
        
        // Open the URL which will be handled by SceneDelegate.openURLContexts
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                print("Successfully opened Wikipedia app")
            } else {
                print("Failed to open Wikipedia app")
            }
        }
    }
}

// Extend the App Intent to make it discoverable in the Shortcuts app
@available(iOS 16.0, *)
extension WikipediaSearchIntent: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: WikipediaSearchIntent(),
                phrases: [
                    "Search Wikipedia for \(\.$searchTerm)",
                    "Find \(\.$searchTerm) on Wikipedia",
                    "Look up \(\.$searchTerm) on Wikipedia",
                    "Wikipedia \(\.$searchTerm)"
                ],
                shortTitle: "Search Wikipedia",
                systemImageName: "magnifyingglass"
            )
        ]
    }
}
