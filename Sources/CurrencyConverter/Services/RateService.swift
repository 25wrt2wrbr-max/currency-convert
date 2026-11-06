import Foundation

enum RateError: LocalizedError {
    case invalidURL
    case http(Int)
    case empty
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build the request."
        case .http(let code):
            return "The rate service returned HTTP \(code)."
        case .empty:
            return "No rate data was returned."
        case .decode(let detail):
            return "Could not read rate data (\(detail))."
        }
    }
}

enum RateService {
    private static let geckoVs: Set<String> = [
        "usd", "php", "gbp", "eur", "cny", "jpy", "chf", "btc", "eth", "bnb"
    ]

    static func liveUSDPerUnit() async throws -> [Currency: Double] {
        async let gecko = optional { try await fetchCoinGeckoSpotUSD() }
        async let frank = optional { try await fetchFrankfurterUnitsPerUSD() }
        async let table = optional { try await fetchCurrencyAPIUnitsPerUSD() }

        let geckoUSD = await gecko
        let frankfurter = await frank
        let fallback = await table

        var usdPerUnit: [Currency: Double] = [.usd: 1]

        if let frankfurter {
            for currency in Currency.allCases where currency.isFiat && currency != .usd {
                if let units = frankfurter[currency.apiCode], units != 0 {
                    usdPerUnit[currency] = 1 / units
                }
            }
        }

        if let geckoUSD {
            for (currency, usd) in geckoUSD where usd > 0 {
                usdPerUnit[currency] = usd
            }
        }

        if usdPerUnit.count < Currency.allCases.count, let fallback {
            for currency in Currency.allCases where usdPerUnit[currency] == nil {
                let key = currency.apiCode.lowercased()
                if let units = fallback[key], units != 0 {
                    usdPerUnit[currency] = 1 / units
                }
            }
        }

        usdPerUnit[.usd] = 1
        guard usdPerUnit.count == Currency.allCases.count else {
            throw RateError.empty
        }
        return usdPerUnit
    }

    static func historicalPair(from: Currency, to: Currency, days: Int = 90) async throws -> [RatePoint] {
        let end = Date()
        let start = Calendar.utc.date(byAdding: .day, value: -days, to: end) ?? end.addingTimeInterval(-Double(days) * 86_400)

        if from == to {
            return daily(from: start, to: end, value: 1)
        }

        if from.isFiat && to.isFiat {
            return try await frankfurterSeries(base: from.apiCode, symbol: to.apiCode, start: start, end: end)
        }

        if from.isCrypto, let id = from.coinGeckoID, geckoVs.contains(to.geckoVs) {
            return try await coinGeckoChart(id: id, vs: to.geckoVs)
        }

        if to.isCrypto, let id = to.coinGeckoID, geckoVs.contains(from.geckoVs) {
            let inverted = try await coinGeckoChart(id: id, vs: from.geckoVs)
            return inverted.compactMap { point in
                guard point.rate != 0 else { return nil }
                return RatePoint(date: point.date, rate: 1 / point.rate)
            }
        }

        async let fromUSD = usdPerUnitSeries(for: from, start: start, end: end)
        async let toUSD = usdPerUnitSeries(for: to, start: start, end: end)
        return join(try await fromUSD, try await toUSD) { lhs, rhs in
            guard rhs != 0 else { return nil }
            return lhs / rhs
        }
    }

    // MARK: - Sources

    private static func fetchCoinGeckoSpotUSD() async throws -> [Currency: Double] {
        let ids = Currency.allCases.compactMap(\.coinGeckoID).joined(separator: ",")
        let url = try url("https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd")
        let raw: [String: [String: Double]] = try await getJSON(url)
        var result: [Currency: Double] = [:]
        for currency in Currency.allCases {
            guard let id = currency.coinGeckoID, let usd = raw[id]?["usd"], usd > 0 else { continue }
            result[currency] = usd
        }
        if result.isEmpty { throw RateError.empty }
        return result
    }

    private static func fetchFrankfurterUnitsPerUSD() async throws -> [String: Double] {
        let symbols = Currency.allCases.filter { $0.isFiat && $0 != .usd }.map(\.apiCode).joined(separator: ",")
        let url = try url("https://api.frankfurter.dev/v1/latest?base=USD&symbols=\(symbols)")
        let decoded: FrankfurterLatest = try await getJSON(url)
        if decoded.rates.isEmpty { throw RateError.empty }
        return decoded.rates
    }

    private static func fetchCurrencyAPIUnitsPerUSD() async throws -> [String: Double] {
        let mirrors = [
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json",
            "https://latest.currency-api.pages.dev/v1/currencies/usd.min.json"
        ]
        var lastError: Error = RateError.empty
        for spec in mirrors {
            do {
                let decoded: CurrencyAPIResponse = try await getJSON(try url(spec))
                if let usd = decoded.usd, !usd.isEmpty {
                    return usd
                }
                lastError = RateError.empty
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func usdPerUnitSeries(for currency: Currency, start: Date, end: Date) async throws -> [RatePoint] {
        if currency == .usd {
            return daily(from: start, to: end, value: 1)
        }
        if currency.isCrypto, let id = currency.coinGeckoID {
            return try await coinGeckoChart(id: id, vs: "usd")
        }
        let unitsPerUSD = try await frankfurterSeries(base: "USD", symbol: currency.apiCode, start: start, end: end)
        return unitsPerUSD.compactMap { point in
            guard point.rate != 0 else { return nil }
            return RatePoint(date: point.date, rate: 1 / point.rate)
        }
    }

    private static func frankfurterSeries(base: String, symbol: String, start: Date, end: Date) async throws -> [RatePoint] {
        let startText = DateFormatting.string(from: start)
        let endText = DateFormatting.string(from: end)
        let url = try url("https://api.frankfurter.dev/v1/\(startText)..\(endText)?base=\(base)&symbols=\(symbol)")
        let decoded: FrankfurterSeries = try await getJSON(url)
        let points: [RatePoint] = decoded.rates.compactMap { day, table in
            guard let value = table[symbol], let date = DateFormatting.date(from: day) else { return nil }
            return RatePoint(date: date, rate: value)
        }
        .sorted { $0.date < $1.date }
        if points.isEmpty { throw RateError.empty }
        return points
    }

    private static func coinGeckoChart(id: String, vs: String) async throws -> [RatePoint] {
        let withInterval = "https://api.coingecko.com/api/v3/coins/\(id)/market_chart?vs_currency=\(vs)&days=90&interval=daily"
        let withoutInterval = "https://api.coingecko.com/api/v3/coins/\(id)/market_chart?vs_currency=\(vs)&days=90"
        let decoded: GeckoChart
        do {
            decoded = try await getJSON(try url(withInterval))
        } catch {
            decoded = try await getJSON(try url(withoutInterval))
        }
        var byDay: [String: RatePoint] = [:]
        for pair in decoded.prices where pair.count >= 2 {
            let date = Date(timeIntervalSince1970: pair[0] / 1000)
            let key = DateFormatting.string(from: date)
            byDay[key] = RatePoint(date: DateFormatting.date(from: key) ?? date, rate: pair[1])
        }
        let points = byDay.values.sorted { $0.date < $1.date }
        if points.isEmpty { throw RateError.empty }
        return points
    }

    // MARK: - Networking

    private static func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("CurrencyConverter/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { throw RateError.http(code) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RateError.decode(error.localizedDescription)
        }
    }

    private static func url(_ string: String) throws -> URL {
        guard let url = URL(string: string) else { throw RateError.invalidURL }
        return url
    }

    private static func optional<T>(_ work: () async throws -> T) async -> T? {
        do { return try await work() } catch { return nil }
    }

    private static func daily(from start: Date, to end: Date, value: Double) -> [RatePoint] {
        var points: [RatePoint] = []
        var day = DateFormatting.startOfDay(start)
        let last = DateFormatting.startOfDay(end)
        while day <= last {
            points.append(RatePoint(date: day, rate: value))
            day = Calendar.utc.date(byAdding: .day, value: 1, to: day) ?? last.addingTimeInterval(1)
        }
        return points
    }

    private static func join(
        _ lhs: [RatePoint],
        _ rhs: [RatePoint],
        combine: (Double, Double) -> Double?
    ) -> [RatePoint] {
        let rhsMap = Dictionary(uniqueKeysWithValues: rhs.map { (DateFormatting.string(from: $0.date), $0.rate) })
        return lhs.compactMap { point in
            let key = DateFormatting.string(from: point.date)
            guard let other = rhsMap[key], let value = combine(point.rate, other) else { return nil }
            return RatePoint(date: point.date, rate: value)
        }
        .sorted { $0.date < $1.date }
    }
}

private struct FrankfurterLatest: Decodable {
    let rates: [String: Double]
}

private struct FrankfurterSeries: Decodable {
    let rates: [String: [String: Double]]
}

private struct GeckoChart: Decodable {
    let prices: [[Double]]
}

private struct CurrencyAPIResponse: Decodable {
    let date: String?
    let usd: [String: Double]?
}

enum DateFormatting {
    static func string(from date: Date) -> String {
        let parts = Calendar.utc.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(from string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.utc.startOfDay(for: date)
    }
}

extension Calendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()
}
