import Foundation

public struct Price: Codable, Equatable {
    let amount: Decimal
    let currency: Currency
    
    init(amount: Decimal, currency: Currency = .usd) {
        self.amount = amount
        self.currency = currency
    }
    
    // MARK: - Formatting
    
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency.symbol)\(amount)"
    }
    
    // MARK: - Currency Conversion
    
    func convertedTo(_ targetCurrency: Currency) -> Price {
        // Use the CurrencyManager to handle the conversion
        return CurrencyManager.shared.convert(self, to: targetCurrency)
    }
    
    // Convert to the user's default currency
    func convertedToDefaultCurrency() -> Price {
        let userPreferences = UserDefaults.standard
        guard let currencyString = userPreferences.string(forKey: "defaultCurrency"),
              let defaultCurrency = Currency(rawValue: currencyString) else {
            return self
        }
        
        return convertedTo(defaultCurrency)
    }
    
    // MARK: - Database Conversion
    
    var databaseValue: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
    
    static func fromDatabase(_ value: Double) -> Price? {
        guard value > 0 else { return nil }
        return Price(amount: Decimal(value))
    }
    
    // MARK: - Validation
    
    static func isValid(_ amount: Decimal) -> Bool {
        amount >= 0 && amount <= 1_000_000_000 // Reasonable maximum for most items
    }
}

// MARK: - Currency Support
extension Price {
    enum Currency: String, Codable, CaseIterable {
        case usd = "USD"
        case eur = "EUR"
        case gbp = "GBP"
        case jpy = "JPY"
        case cad = "CAD"
        case aud = "AUD"
        
        var code: String { rawValue }
        
        var symbol: String {
            switch self {
            case .usd: return "$"
            case .eur: return "€"
            case .gbp: return "£"
            case .jpy: return "¥"
            case .cad: return "C$"
            case .aud: return "A$"
            }
        }
        
        var name: String {
            switch self {
            case .usd: return "US Dollar"
            case .eur: return "Euro"
            case .gbp: return "British Pound"
            case .jpy: return "Japanese Yen"
            case .cad: return "Canadian Dollar"
            case .aud: return "Australian Dollar"
            }
        }
    }
}

// MARK: - CSV Export Support
extension Price {
    var csvValue: String {
        "\(amount),\(currency.code)"
    }
    
    static func fromCSV(_ value: String) -> Price? {
        let components = value.split(separator: ",")
        guard components.count == 2,
              let amount = Decimal(string: String(components[0])),
              let currency = Currency(rawValue: String(components[1])),
              isValid(amount) else {
            return nil
        }
        return Price(amount: amount, currency: currency)
    }
} 