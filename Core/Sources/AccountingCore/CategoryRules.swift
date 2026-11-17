import Foundation

public enum CategoryRules {

    public static let defaults: [String] = [
        "Groceries",
        "Housing",
        "Transport",
        "Leisure",
        "Health",
        "Shopping",
        "Subscriptions",
        "Salary",
        "Dividends",
        "Interest",
        "Fees",
        "Taxes",
        "Investments",
        "Transfers",
        "Other"
    ]

    // Bank types
    // a TRANSFER alone doesn't prove that both accounts belong to the user, so it stays unknown until it is paired
    private static let typeRules: [(kind: TransactionKind, types: Set<String>)] = [
        (.investmentBuy, ["BUY", "SECURITY_BUY", "SAVINGS_PLAN", "SPARPLAN", "KAUF"]),
        (.investmentSell, ["SELL", "SECURITY_SELL", "VERKAUF"]),
        (.dividend, ["DIVIDEND", "DIVIDENDE"]),
        (.interest, ["INTEREST", "ZINSEN"]),
        (.fee, ["FEE", "FEE_CHARGE", "GEBUEHR"]),
        (.tax, ["TAX", "STEUER"]),
        (.unknown, ["TRANSFER", "INTERNAL_TRANSFER", "UMBUCHUNG"])
    ]

    // Keywords
    // order matters, first match wins
    private static let keywordRules: [(category: String, words: [String])] = [
        ("Groceries", ["rewe", "aldi", "lidl", "edeka", "penny", "supermarkt", "supermarket"]),
        ("Housing", ["miete", "vermieter", "nebenkosten", "strom", "gasabschlag", "landlord"]),
        ("Transport", ["deutsche bahn", "db vertrieb", "uber", "taxi", "tankstelle", "aral"]),
        ("Subscriptions", ["netflix", "spotify", "icloud", "abo"]),
        ("Health", ["apotheke", "arzt", "zahnarzt"]),
        ("Shopping", ["amazon", "zalando", "ikea"]),
        ("Salary", ["gehalt", "lohn", "salary"]),
        ("Leisure", ["kino", "restaurant", "cafe", "café", "bar"])
    ]

    // Kind
    public static func kind(type rawType: String?, text: String, amountMinor: Int64) -> TransactionKind {
        let type = (rawType ?? "").uppercased().replacingOccurrences(of: " ", with: "_")
        let text = text.lowercased()

        if let rule = typeRules.first(where: { $0.types.contains(type) }) {
            return rule.kind
        }

        if text.contains("dividende") {
            return .dividend
        }
        if text.contains("zinsgutschrift") || text.contains("interest payment") {
            return .interest
        }
        if text.contains("depotgebühr") || text.contains("kontoführung") {
            return .fee
        }

        if amountMinor > 0 {
            return .income
        }
        if amountMinor < 0 {
            return .expense
        }
        return .unknown
    }

    // Category
    public static func category(for kind: TransactionKind, text: String) -> String {
        switch kind {
        case .investmentBuy, .investmentSell: return "Investments"
        case .transfer: return "Transfers"
        case .dividend: return "Dividends"
        case .interest: return "Interest"
        case .fee: return "Fees"
        case .tax: return "Taxes"
        default: break
        }

        let folded = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "de_DE")
        )

        for rule in keywordRules where rule.words.contains(where: folded.contains) {
            return rule.category
        }
        return "Other"
    }
}
