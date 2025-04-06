import SwiftUI
import WidgetKit
import WMF
import WMFComponents

// MARK: - Widget

struct SearchWidget: Widget {
    private let kind: String = WidgetController.SupportedWidget.search.identifier
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SearchProvider(), content: { entry in
            SearchWidgetView(entry: entry)
        })
        .configurationDisplayName(SearchWidget.LocalizedStrings.widgetTitle)
        .description(SearchWidget.LocalizedStrings.widgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

// MARK: - Timeline Entry

struct SearchEntry: TimelineEntry {
    var date: Date
    var recentSearchTerms: [String]?
}

// MARK: - Timeline Provider

struct SearchProvider: TimelineProvider {
    typealias Entry = SearchEntry
    
    func placeholder(in context: Context) -> SearchEntry {
        return SearchEntry(date: Date(), recentSearchTerms: ["Wikipedia", "iOS", "Swift"])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SearchEntry) -> Void) {
        let placeholderTerms = ["Wikipedia", "iOS", "Swift"]
        completion(SearchEntry(date: Date(), recentSearchTerms: context.isPreview ? placeholderTerms : fetchRecentSearchTerms()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SearchEntry>) -> Void) {
        let currentDate = Date()
        let entry = SearchEntry(date: currentDate, recentSearchTerms: fetchRecentSearchTerms())
        
        // Refresh the widget once per day to show updated recent searches
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        let midnight = Calendar.current.startOfDay(for: tomorrow)
        
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
    
    private func fetchRecentSearchTerms() -> [String]? {
        // Get recent search terms from user defaults in the shared container
        guard let userDefaults = UserDefaults(suiteName: WMFApplicationGroupIdentifier) else {
            return nil
        }
        
        let recentSearches = userDefaults.object(forKey: "WMFRecentSearches") as? [String]
        return recentSearches?.prefix(5).map { $0 } ?? []
    }
}

// MARK: - Widget Views

struct SearchWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.redactionReasons) private var redactionReasons
    
    var entry: SearchEntry
    
    var body: some View {
        ZStack {
            backgroundView
            
            switch widgetFamily {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            default:
                smallWidgetView
            }
        }
    }
    
    var backgroundView: some View {
        Color(colorScheme == .light ? Theme.light.colors.paperBackground : Theme.dark.colors.paperBackground)
    }
    
    // Small widget is a simple search button
    var smallWidgetView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.link : Theme.dark.colors.link))
            
            Text(SearchWidget.LocalizedStrings.searchWikipedia)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.primaryText : Theme.dark.colors.primaryText))
                .padding(.horizontal, 8)
            
            Spacer()
                .frame(height: 4)
            
            Text(SearchWidget.LocalizedStrings.tapToSearch)
                .font(.system(size: 12))
                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                .padding(.horizontal, 8)
        }
        .padding()
        .widgetURL(URL(string: "wikipedia://search"))
    }
    
    // Medium widget shows search bar with recent searches
    var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                
                Text(SearchWidget.LocalizedStrings.searchWikipedia)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(colorScheme == .light ? Theme.light.colors.baseBackground : Theme.dark.colors.baseBackground))
            )
            
            if entry.recentSearchTerms?.isEmpty ?? true {
                Text(SearchWidget.LocalizedStrings.noRecentSearches)
                    .font(.system(size: 12))
                    .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                    .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(SearchWidget.LocalizedStrings.recentSearches)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                    
                    ForEach(entry.recentSearchTerms?.prefix(3) ?? [], id: \.self) { term in
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.link : Theme.dark.colors.link))
                            
                            Text(term)
                                .font(.system(size: 14))
                                .lineLimit(1)
                                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.primaryText : Theme.dark.colors.primaryText))
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "wikipedia://search"))
    }
    
    // Large widget shows search bar and more recent searches
    var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                
                Text(SearchWidget.LocalizedStrings.searchWikipedia)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(colorScheme == .light ? Theme.light.colors.baseBackground : Theme.dark.colors.baseBackground))
            )
            
            if entry.recentSearchTerms?.isEmpty ?? true {
                Text(SearchWidget.LocalizedStrings.noRecentSearches)
                    .font(.system(size: 14))
                    .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                    .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SearchWidget.LocalizedStrings.recentSearches)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.secondaryText : Theme.dark.colors.secondaryText))
                    
                    ForEach(entry.recentSearchTerms?.prefix(5) ?? [], id: \.self) { term in
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.link : Theme.dark.colors.link))
                            
                            Text(term)
                                .font(.system(size: 16))
                                .lineLimit(1)
                                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.primaryText : Theme.dark.colors.primaryText))
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                    
                    Text(SearchWidget.LocalizedStrings.tapToSearch)
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(colorScheme == .light ? Theme.light.colors.link : Theme.dark.colors.link))
                
                Spacer()
            }
        }
        .padding()
        .widgetURL(URL(string: "wikipedia://search"))
    }
}

extension SearchWidget {
    
    enum LocalizedStrings {
        
        static var widgetTitle: String {
            return WMFLocalizedString("search-widget-title", value: "Wikipedia Search", comment: "Title of the Search Widget")
        }
        
        static var widgetDescription: String {
            return WMFLocalizedString("search-widget-description", value: "Quick access to Wikipedia search", comment: "Description of the Search Widget")
        }
        
        static var searchWikipedia: String {
            return WMFLocalizedString("search-widget-search-wikipedia", value: "Search Wikipedia", comment: "Prompt to search Wikipedia in the Search Widget")
        }
        
        static var recentSearches: String {
            return WMFLocalizedString("search-widget-recent-searches", value: "Recent searches", comment: "Header for recent searches section in the Search Widget")
        }
        
        static var noRecentSearches: String {
            return WMFLocalizedString("search-widget-no-recent-searches", value: "No recent searches", comment: "Message shown when there are no recent searches in the Search Widget")
        }
        
        static var tapToSearch: String {
            return WMFLocalizedString("search-widget-tap-to-search", value: "Tap to search", comment: "Instruction to tap the widget to search")
        }
    }
}
