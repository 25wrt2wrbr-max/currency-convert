import SwiftUI

enum Currency: String, CaseIterable, Identifiable, Codable, Sendable {
    case usd, php, btc, eth, sol, bnb, gbp, eur, rmb, jpy, chf

    var id: String { rawValue }

    var displayCode: String {
        self == .rmb ? "RMB" : rawValue.uppercased()
    }

    var apiCode: String {
        self == .rmb ? "CNY" : rawValue.uppercased()
    }

    var geckoVs: String {
        apiCode.lowercased()
    }

    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .php: return "Philippine Peso"
        case .btc: return "Bitcoin"
        case .eth: return "Ethereum"
        case .sol: return "Solana"
        case .bnb: return "BNB"
        case .gbp: return "British Pound"
        case .eur: return "Euro"
        case .rmb: return "Chinese Yuan"
        case .jpy: return "Japanese Yen"
        case .chf: return "Swiss Franc"
        }
    }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .php: return "₱"
        case .btc: return "₿"
        case .eth: return "Ξ"
        case .sol: return "◎"
        case .bnb: return "BNB"
        case .gbp: return "£"
        case .eur: return "€"
        case .rmb: return "¥"
        case .jpy: return "¥"
        case .chf: return "Fr"
        }
    }

    var badge: String {
        switch self {
        case .usd: return "🇺🇸"
        case .php: return "🇵🇭"
        case .btc: return "₿"
        case .eth: return "Ξ"
        case .sol: return "◎"
        case .bnb: return "B"
        case .gbp: return "🇬🇧"
        case .eur: return "🇪🇺"
        case .rmb: return "🇨🇳"
        case .jpy: return "🇯🇵"
        case .chf: return "🇨🇭"
        }
    }

    var isCrypto: Bool {
        switch self {
        case .btc, .eth, .sol, .bnb: return true
        default: return false
        }
    }

    var isFiat: Bool { !isCrypto }

    var coinGeckoID: String? {
        switch self {
        case .btc: return "bitcoin"
        case .eth: return "ethereum"
        case .sol: return "solana"
        case .bnb: return "binancecoin"
        default: return nil
        }
    }

    var tint: Color {
        switch self {
        case .usd: return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .php: return Color(red: 0.00, green: 0.22, blue: 0.66)
        case .btc: return Color(red: 0.97, green: 0.58, blue: 0.10)
        case .eth: return Color(red: 0.39, green: 0.47, blue: 0.93)
        case .sol: return Color(red: 0.60, green: 0.27, blue: 1.00)
        case .bnb: return Color(red: 0.95, green: 0.73, blue: 0.18)
        case .gbp: return Color(red: 0.78, green: 0.06, blue: 0.18)
        case .eur: return Color(red: 0.00, green: 0.20, blue: 0.60)
        case .rmb: return Color(red: 0.87, green: 0.16, blue: 0.06)
        case .jpy: return Color(red: 0.74, green: 0.00, blue: 0.18)
        case .chf: return Color(red: 0.86, green: 0.08, blue: 0.08)
        }
    }

    var usesEmojiBadge: Bool {
        switch self {
        case .btc, .eth, .sol, .bnb: return false
        default: return true
        }
    }
}

enum Side: String, Sendable {
    case from, to
}

struct RatePoint: Identifiable, Sendable, Equatable {
    var id: Date { date }
    let date: Date
    let rate: Double
}

struct ChartStats: Sendable, Equatable {
    let start: Double
    let end: Double
    let high: Double
    let low: Double
    let average: Double
    let changePercent: Double
}

enum Palette {
    static let accent = Color(red: 0.18, green: 0.75, blue: 0.64)
    static let up = Color(red: 0.16, green: 0.78, blue: 0.52)
    static let down = Color(red: 0.96, green: 0.33, blue: 0.42)
    static let cardRadius: CGFloat = 24
}
