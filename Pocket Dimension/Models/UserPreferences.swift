import SwiftUI

/**
 Manages and persists user preferences across app sessions.
 
 This class handles user-configurable settings like theme, view style, display options,
 and default values. All preferences are stored in UserDefaults and observed via SwiftUI's
 @Published property wrapper to trigger UI updates when changed.
 
 ## Usage
 
 ```swift
 // Access user preferences in a view
 struct ContentView: View {
     @EnvironmentObject var userPreferences: UserPreferences
     
     var body: some View {
         NavigationView {
             List {
                 // Use preferences to determine appearance
                 if userPreferences.viewStyle == .list {
                     listContent
                 } else {
                     gridContent
                 }
             }
         }
         .preferredColorScheme(userPreferences.theme.colorScheme)
     }
 }
 ```
 
 ## Adding New Preferences
 
 To add a new user preference:
 1. Add a property key constant
 2. Add a @Published property with persistence in didSet
 3. Initialize the property in init() from UserDefaults
 4. Create UI controls in settings to modify the preference
 */
class UserPreferences: ObservableObject {
    // MARK: - Preference Types
    
    /**
     Defines app theme options.
     
     - `system`: Follow the system theme (light/dark)
     - `light`: Always use light theme
     - `dark`: Always use dark theme
     */
    enum Theme: String, CaseIterable, Codable {
        /// Follow the system theme (light/dark)
        case system
        
        /// Always use light theme
        case light
        
        /// Always use dark theme
        case dark
        
        /// The corresponding SwiftUI ColorScheme (nil for system)
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    /**
     Defines item display layout options.
     
     - `grid`: Items displayed in a grid (multiple columns)
     - `list`: Items displayed in a single column list
     - `compact`: Dense grid with smaller items
     */
    enum ViewStyle: String, CaseIterable, Codable {
        /// Items displayed in a grid (multiple columns)
        case grid
        
        /// Items displayed in a single column list
        case list
        
        /// Dense grid with smaller items
        case compact
        
        /// Grid configuration for LazyVGrid
        var columns: [GridItem] {
            switch self {
            case .grid: return [GridItem(.adaptive(minimum: 160))]
            case .list: return [GridItem(.flexible())]
            case .compact: return [GridItem(.adaptive(minimum: 100))]
            }
        }
    }
    
    /**
     Defines which information should be displayed for items in lists.
     
     - `type`: Show the item type (Book, Manga, etc.)
     - `location`: Show the item's storage location
     - `price`: Show the item's price
     - `none`: Don't show any additional information
     */
    enum ItemInfoDisplayOption: String, CaseIterable, Codable {
        /// Show the item type (Book, Manga, etc.)
        case type = "Type"
        
        /// Show the item's storage location
        case location = "Location"
        
        /// Show the item's price
        case price = "Price"
        
        /// Don't show any additional information
        case none = "None"
        
        /// Default display options for new users
        static var defaultOptions: [ItemInfoDisplayOption] {
            [.type, .location, .price]
        }
    }
    
    // MARK: - Storage Keys
    
    /// UserDefaults storage keys
    private let defaults = UserDefaults.standard
    private let themeKey = "userTheme"
    private let viewStyleKey = "viewStyle"
    private let viewModeKey = "viewMode"
    private let showCompletionStatusKey = "showCompletionStatus"
    private let defaultCollectionKey = "defaultCollection"
    private let defaultCurrencyKey = "defaultCurrency"
    private let itemInfoDisplayOptionsKey = "itemInfoDisplayOptions"
    
    // MARK: - Published Properties
    
    /// The app theme (system, light, or dark)
    @Published var theme: Theme {
        didSet {
            defaults.set(theme.rawValue, forKey: themeKey)
        }
    }
    
    /// The item display layout style
    @Published var viewStyle: ViewStyle {
        didSet {
            defaults.set(viewStyle.rawValue, forKey: viewStyleKey)
        }
    }
    
    /// The preferred view mode for collections (list vs card)
    @Published var viewMode: ViewMode {
        didSet {
            defaults.set(viewMode.rawValue, forKey: viewModeKey)
        }
    }
    
    /// Whether to show completion status for series
    @Published var showCompletionStatus: Bool {
        didSet {
            defaults.set(showCompletionStatus, forKey: showCompletionStatusKey)
        }
    }
    
    /// The default collection type for new items
    @Published var defaultCollection: CollectionType {
        didSet {
            defaults.set(defaultCollection.rawValue, forKey: defaultCollectionKey)
        }
    }
    
    /// The default currency for prices
    @Published var defaultCurrency: Price.Currency {
        didSet {
            defaults.set(defaultCurrency.rawValue, forKey: defaultCurrencyKey)
            // Post notification for currency change
            NotificationCenter.default.post(
                name: Notification.Name("DefaultCurrencyChanged"),
                object: defaultCurrency
            )
        }
    }
    
    /// Information to display in item lists
    @Published var itemInfoDisplayOptions: [ItemInfoDisplayOption] {
        didSet {
            if let encoded = try? JSONEncoder().encode(itemInfoDisplayOptions) {
                defaults.set(encoded, forKey: itemInfoDisplayOptionsKey)
            }
        }
    }
    
    // MARK: - Initialization
    
    /**
     Initializes the UserPreferences with values from UserDefaults.
     
     If preferences don't exist in UserDefaults, default values are used.
     */
    init() {
        // Load saved theme or use system default
        self.theme = Theme(rawValue: defaults.string(forKey: themeKey) ?? "") ?? .system
        
        // Load saved view style or use grid default
        self.viewStyle = ViewStyle(rawValue: defaults.string(forKey: viewStyleKey) ?? "") ?? .grid
        
        // Load saved view mode or use list default
        self.viewMode = ViewMode(rawValue: defaults.string(forKey: viewModeKey) ?? "") ?? .list
        
        // Load saved completion status or use true as default
        self.showCompletionStatus = defaults.bool(forKey: showCompletionStatusKey)
        
        // Load saved default collection or use books as default
        self.defaultCollection = CollectionType(rawValue: defaults.string(forKey: defaultCollectionKey) ?? "") ?? .books
        
        // Load saved default currency or use USD as default
        if let currencyString = defaults.string(forKey: defaultCurrencyKey),
           let currency = Price.Currency(rawValue: currencyString) {
            self.defaultCurrency = currency
        } else {
            self.defaultCurrency = .usd
        }
        
        // Load saved item info display options or use defaults
        if let savedOptionsData = defaults.data(forKey: itemInfoDisplayOptionsKey),
           let decodedOptions = try? JSONDecoder().decode([ItemInfoDisplayOption].self, from: savedOptionsData) {
            self.itemInfoDisplayOptions = decodedOptions
        } else {
            self.itemInfoDisplayOptions = ItemInfoDisplayOption.defaultOptions
        }
    }
} 