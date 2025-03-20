import SwiftUI

class UserPreferences: ObservableObject {
    enum Theme: String, CaseIterable, Codable {
        case system
        case light
        case dark
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    enum ViewStyle: String, CaseIterable, Codable {
        case grid
        case list
        case compact
        
        var columns: [GridItem] {
            switch self {
            case .grid: return [GridItem(.adaptive(minimum: 160))]
            case .list: return [GridItem(.flexible())]
            case .compact: return [GridItem(.adaptive(minimum: 100))]
            }
        }
    }
    
    // New enum for item info display options
    enum ItemInfoDisplayOption: String, CaseIterable, Codable {
        case type = "Type"
        case location = "Location"
        case price = "Price"
        case none = "None"
        
        static var defaultOptions: [ItemInfoDisplayOption] {
            [.type, .location, .price]
        }
    }
    
    private let defaults = UserDefaults.standard
    private let themeKey = "userTheme"
    private let viewStyleKey = "viewStyle"
    private let showCompletionStatusKey = "showCompletionStatus"
    private let defaultCollectionKey = "defaultCollection"
    private let defaultCurrencyKey = "defaultCurrency"
    private let itemInfoDisplayOptionsKey = "itemInfoDisplayOptions"
    
    @Published var theme: Theme {
        didSet {
            defaults.set(theme.rawValue, forKey: themeKey)
        }
    }
    
    @Published var viewStyle: ViewStyle {
        didSet {
            defaults.set(viewStyle.rawValue, forKey: viewStyleKey)
        }
    }
    
    @Published var showCompletionStatus: Bool {
        didSet {
            defaults.set(showCompletionStatus, forKey: showCompletionStatusKey)
        }
    }
    
    @Published var defaultCollection: CollectionType {
        didSet {
            defaults.set(defaultCollection.rawValue, forKey: defaultCollectionKey)
        }
    }
    
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
    
    // Add new property for item info display options
    @Published var itemInfoDisplayOptions: [ItemInfoDisplayOption] {
        didSet {
            if let encoded = try? JSONEncoder().encode(itemInfoDisplayOptions) {
                defaults.set(encoded, forKey: itemInfoDisplayOptionsKey)
            }
        }
    }
    
    init() {
        // Load saved theme or use system default
        self.theme = Theme(rawValue: defaults.string(forKey: themeKey) ?? "") ?? .system
        
        // Load saved view style or use grid default
        self.viewStyle = ViewStyle(rawValue: defaults.string(forKey: viewStyleKey) ?? "") ?? .grid
        
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