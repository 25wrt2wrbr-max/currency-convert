import Foundation

final class SelfTestResult: @unchecked Sendable {
    var failed = false
}

enum SelfTest {
    static func run() async throws {
        let live = try await RateService.liveUSDPerUnit()
        guard live.count == Currency.allCases.count else {
            throw RateError.empty
        }
        for currency in Currency.allCases {
            guard let value = live[currency], value > 0 else {
                throw RateError.empty
            }
            print("LIVE \(currency.displayCode)=\(value)")
        }

        guard let usd = live[.usd], let php = live[.php], php > 0 else {
            throw RateError.empty
        }
        let usdToPhp = (usd / php) * 100
        print("CONVERT 100 USD = \(usdToPhp) PHP")

        guard let btc = live[.btc], btc > 0 else { throw RateError.empty }
        print("CONVERT 1 BTC = \(btc / php) PHP")

        let fiatChart = try await RateService.historicalPair(from: .usd, to: .php)
        print("CHART USD/PHP points=\(fiatChart.count) first=\(fiatChart.first.map { "\($0.date) \($0.rate)" } ?? "none") last=\(fiatChart.last.map { "\($0.date) \($0.rate)" } ?? "none")")
        guard fiatChart.count >= 50 else { throw RateError.empty }

        let cryptoChart = try await RateService.historicalPair(from: .btc, to: .usd)
        print("CHART BTC/USD points=\(cryptoChart.count) last=\(cryptoChart.last.map { String($0.rate) } ?? "none")")
        guard cryptoChart.count >= 50 else { throw RateError.empty }

        let mixedChart = try await RateService.historicalPair(from: .eth, to: .php)
        print("CHART ETH/PHP points=\(mixedChart.count)")
        guard mixedChart.count >= 50 else { throw RateError.empty }

        print("SELFTEST_OK")
    }
}
