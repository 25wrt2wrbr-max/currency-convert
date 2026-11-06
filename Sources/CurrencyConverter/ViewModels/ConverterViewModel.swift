import AppKit
import Foundation

@MainActor
@Observable
final class ConverterViewModel {
    var from: Currency = .usd
    var to: Currency = .php
    var fromText: String = "100"
    var toText: String = ""
    var editing: Side = .from
    var points: [RatePoint] = []
    var selectedPoint: RatePoint?
    var isLoadingLive = false
    var isLoadingChart = false
    var liveError: String?
    var chartError: String?
    var updatedAt: Date?

    private var usdPerUnit: [Currency: Double] = [:]
    private var chartTask: Task<Void, Never>?
    private var cachedChartKey: String?
    private var cachedChartAt: Date?

    var rate: Double? {
        guard let fromUSD = usdPerUnit[from], let toUSD = usdPerUnit[to], toUSD != 0 else { return nil }
        return fromUSD / toUSD
    }

    var inverseRate: Double? {
        guard let rate, rate != 0 else { return nil }
        return 1 / rate
    }

    var convertedPreview: Double? {
        guard let rate, let amount = parse(fromText) else { return nil }
        return amount * rate
    }

    var stats: ChartStats? {
        guard points.count >= 2 else { return nil }
        let values = points.map(\.rate)
        guard let start = values.first, let end = values.last,
              let high = values.max(), let low = values.min() else { return nil }
        let average = values.reduce(0, +) / Double(values.count)
        let change = start == 0 ? 0 : ((end - start) / start) * 100
        return ChartStats(start: start, end: end, high: high, low: low, average: average, changePercent: change)
    }

    var trendUp: Bool {
        (stats?.changePercent ?? 0) >= 0
    }

    var updatedLabel: String {
        guard let updatedAt else { return "Waiting for rates" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "Updated \(formatter.string(from: updatedAt))"
    }

    func start() async {
        await refresh(force: true)
    }

    func refresh(force: Bool = false) async {
        await loadLive()
        await loadChart(force: force)
    }

    func setFrom(_ currency: Currency) {
        if currency == to {
            to = from
        }
        from = currency
        applyRate()
        scheduleChart()
    }

    func setTo(_ currency: Currency) {
        if currency == from {
            from = to
        }
        to = currency
        applyRate()
        scheduleChart()
    }

    func swap() {
        let previousFrom = from
        from = to
        to = previousFrom
        if editing == .from {
            fromText = toText.isEmpty ? fromText : stripGrouping(toText)
        } else {
            toText = fromText
        }
        applyRate()
        scheduleChart()
    }

    func edit(_ side: Side, text: String) {
        editing = side
        if side == .from {
            fromText = sanitize(text)
        } else {
            toText = sanitize(text)
        }
        applyRate()
    }

    func applyQuickAmount(_ value: Double) {
        editing = .from
        fromText = format(value, for: from, grouping: false)
        applyRate()
    }

    func copyResult() {
        let text = toText.isEmpty ? fromText : toText
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(text) \(to.displayCode)", forType: .string)
    }

    func selectNearest(to date: Date) {
        selectedPoint = nearest(to: date)
    }

    func clearSelection() {
        selectedPoint = nil
    }

    func applyRate() {
        guard let rate else { return }
        if editing == .from {
            if let value = parse(fromText) {
                toText = format(value * rate, for: to, grouping: true)
            } else if fromText.isEmpty {
                toText = ""
            }
        } else {
            if let value = parse(toText), rate != 0 {
                fromText = format(value / rate, for: from, grouping: true)
            } else if toText.isEmpty {
                fromText = ""
            }
        }
    }

    private func loadLive() async {
        isLoadingLive = true
        liveError = nil
        defer { isLoadingLive = false }
        do {
            usdPerUnit = try await RateService.liveUSDPerUnit()
            updatedAt = Date()
            applyRate()
        } catch {
            liveError = error.localizedDescription
        }
    }

    private func scheduleChart() {
        chartTask?.cancel()
        chartTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self, !Task.isCancelled else { return }
            await self.loadChart(force: false)
        }
    }

    private func loadChart(force: Bool) async {
        let key = "\(from.rawValue)-\(to.rawValue)"
        if !force, cachedChartKey == key, let cachedChartAt, Date().timeIntervalSince(cachedChartAt) < 600, !points.isEmpty {
            return
        }
        isLoadingChart = true
        chartError = nil
        selectedPoint = nil
        defer { isLoadingChart = false }
        do {
            let series = try await RateService.historicalPair(from: from, to: to)
            guard !Task.isCancelled else { return }
            points = series
            cachedChartKey = key
            cachedChartAt = Date()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                points = []
                chartError = error.localizedDescription
            }
        }
    }

    private func nearest(to date: Date) -> RatePoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private func parse(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    private func sanitize(_ raw: String) -> String {
        var result = ""
        var seenDot = false
        for character in raw {
            if character.isNumber {
                result.append(character)
            } else if character == "." && !seenDot {
                result.append(character)
                seenDot = true
            } else if character == "," {
                continue
            }
        }
        return result
    }

    private func stripGrouping(_ raw: String) -> String {
        raw.replacingOccurrences(of: ",", with: "")
    }

    func format(_ value: Double, for currency: Currency, grouping: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let places = fractionDigits(for: value, currency: currency)
        formatter.minimumFractionDigits = min(2, places)
        formatter.maximumFractionDigits = places
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    func formatRate(_ value: Double) -> String {
        format(value, for: to, grouping: true)
    }

    private func fractionDigits(for value: Double, currency: Currency) -> Int {
        let magnitude = abs(value)
        if currency == .jpy && magnitude >= 1 { return 2 }
        if magnitude >= 1000 { return 2 }
        if magnitude >= 1 { return 4 }
        if magnitude >= 0.01 { return 6 }
        return 8
    }
}
