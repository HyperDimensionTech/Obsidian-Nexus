import Foundation

class CurrencyManager {
    static let shared = CurrencyManager()
    
    // Default conversion rates relative to USD (as of the implementation date)
    // In a real app, these would be fetched from an API
    private let conversionRates: [Price.Currency: Decimal] = [
        .usd: 1.0,
        .eur: 0.92,
        .gbp: 0.78,
        .jpy: 153.5,
        .cad: 1.36,
        .aud: 1.52
    ]
    
    private init() {
        // Register for notifications about currency changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCurrencyChange),
            name: Notification.Name("DefaultCurrencyChanged"),
            object: nil
        )
    }
    
    @objc private func handleCurrencyChange(notification: Notification) {
        // This method can be expanded if we need to perform actions when currency changes
        if let newCurrency = notification.object as? Price.Currency {
            print("Default currency changed to: \(newCurrency.name)")
        }
    }
    
    // Convert a price to a different currency
    func convert(_ price: Price, to targetCurrency: Price.Currency) -> Price {
        // If already in the target currency, return as is
        if price.currency == targetCurrency {
            return price
        }
        
        // Get conversion rates
        guard let fromRate = conversionRates[price.currency],
              let toRate = conversionRates[targetCurrency] else {
            // If we don't have a rate, return original
            return price
        }
        
        // Calculate converted amount: first to USD, then to target
        let inUSD = price.amount / fromRate
        let inTargetCurrency = inUSD * toRate
        
        // Round to 2 decimal places for most currencies (JPY exception)
        let roundedAmount: Decimal
        if targetCurrency == .jpy {
            roundedAmount = inTargetCurrency.rounded(0)
        } else {
            roundedAmount = inTargetCurrency.rounded(2)
        }
        
        return Price(amount: roundedAmount, currency: targetCurrency)
    }
    
    // Format a price for display using the provided currency
    func formatPrice(_ amount: Decimal, currency: Price.Currency) -> String {
        let price = Price(amount: amount, currency: currency)
        return price.formatted()
    }
    
    // Get current default currency
    var defaultCurrency: Price.Currency {
        UserDefaults.standard.string(forKey: "defaultCurrency")
            .flatMap { Price.Currency(rawValue: $0) } ?? .usd
    }
}

// Extension to help with decimal rounding
extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var result = self
        let roundingMode = NSDecimalNumber.RoundingMode.plain
        
        var localResult = result
        NSDecimalRound(&result, &localResult, scale, roundingMode)
        return result
    }
} 