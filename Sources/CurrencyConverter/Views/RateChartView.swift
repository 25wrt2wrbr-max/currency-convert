import Charts
import SwiftUI

struct RateChartView: View {
    @Bindable var model: ConverterViewModel

    private var lineColor: Color {
        model.trendUp ? Palette.up : Palette.down
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last three months")
                        .font(.headline)
                    Text("Price of 1 \(model.from.displayCode) in \(model.to.displayCode)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let selected = model.selectedPoint {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(selected.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(model.formatRate(selected.rate)) \(model.to.displayCode)")
                            .font(.callout.monospacedDigit().weight(.semibold))
                    }
                }
            }

            chartBody
                .frame(maxWidth: .infinity, minHeight: 250, maxHeight: .infinity)

            statsRow
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }

    @ViewBuilder
    private var chartBody: some View {
        if model.isLoadingChart && model.points.isEmpty {
            ProgressView("Loading 90-day history…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let chartError = model.chartError, model.points.isEmpty {
            ContentUnavailableView(
                "Chart unavailable",
                systemImage: "chart.line.downtrend.xyaxis",
                description: Text(chartError)
            )
        } else if model.points.count < 2 {
            ContentUnavailableView(
                "Not enough history",
                systemImage: "chart.xyaxis.line",
                description: Text("Need at least two daily points to draw this pair.")
            )
        } else {
            Chart(model.points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Rate", point.rate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.32), lineColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Rate", point.rate)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                if let selected = model.selectedPoint {
                    RuleMark(x: .value("Selected", selected.date))
                        .foregroundStyle(.secondary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    PointMark(
                        x: .value("Selected", selected.date),
                        y: .value("Rate", selected.rate)
                    )
                    .foregroundStyle(lineColor)
                    .symbolSize(64)
                }
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisValueLabel {
                        if let rate = value.as(Double.self) {
                            Text(model.formatRate(rate))
                                .font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            .chartPlotStyle { plot in
                plot.background(.clear)
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                select(at: location, proxy: proxy, geo: geo)
                            case .ended:
                                model.clearSelection()
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    select(at: value.location, proxy: proxy, geo: geo)
                                }
                                .onEnded { _ in
                                    model.clearSelection()
                                }
                        )
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            if let stats = model.stats {
                StatChip(title: "High", value: model.formatRate(stats.high))
                StatChip(title: "Low", value: model.formatRate(stats.low))
                StatChip(title: "Average", value: model.formatRate(stats.average))
                StatChip(
                    title: "Change",
                    value: String(format: "%+.2f%%", stats.changePercent),
                    tint: stats.changePercent >= 0 ? Palette.up : Palette.down
                )
            }
            Spacer()
            Text("Frankfurter · CoinGecko")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = model.points.map(\.rate)
        guard let minValue = values.min(), let maxValue = values.max() else { return 0...1 }
        if minValue == maxValue {
            let pad = max(abs(minValue) * 0.05, 0.0001)
            return (minValue - pad)...(maxValue + pad)
        }
        let pad = max((maxValue - minValue) * 0.14, abs(maxValue) * 0.002)
        return (minValue - pad)...(maxValue + pad)
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotRect = geo[plotFrame]
        let x = location.x - plotRect.origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        model.selectNearest(to: date)
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
