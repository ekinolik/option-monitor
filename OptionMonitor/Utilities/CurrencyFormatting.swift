import Foundation

func formatAbbreviatedCurrency(_ amount: Double) -> String {
    let absAmount = abs(amount)
    let sign = amount < 0 ? "-" : ""

    if absAmount >= 1_000_000_000 {
        return "\(sign)$\(String(format: "%.2f", absAmount / 1_000_000_000))B"
    } else if absAmount >= 1_000_000 {
        return "\(sign)$\(String(format: "%.2f", absAmount / 1_000_000))M"
    } else if absAmount >= 1_000 {
        return "\(sign)$\(String(format: "%.2f", absAmount / 1_000))K"
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "$"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "$0"
}
