import SwiftUI

struct ContentView: View {
    @State private var model = ConverterViewModel()
    @State private var swapAngle: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            background
            VStack(spacing: 22) {
                header
                converter
                rateSummary
                RateChartView(model: model)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .task {
            await model.start()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task { await model.refresh(force: false) }
        }
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Palette.accent.opacity(colorScheme == .dark ? 0.16 : 0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(model.from.tint.opacity(0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -280, y: -220)
            Circle()
                .fill(model.to.tint.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 320, y: 240)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Currency Converter")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Fiat and crypto, with a three-month rate history.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                if model.isLoadingLive {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(model.updatedLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await model.refresh(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh rates")
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }

    private var converter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                AmountCard(side: .from, model: model)
                swapButton
                AmountCard(side: .to, model: model)
            }
            VStack(spacing: 14) {
                AmountCard(side: .from, model: model)
                swapButton
                AmountCard(side: .to, model: model)
            }
        }
    }

    private var swapButton: some View {
        Button {
            withAnimation(.spring(duration: 0.45, bounce: 0.32)) {
                swapAngle += 180
                model.swap()
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 15, weight: .semibold))
                .rotationEffect(.degrees(swapAngle))
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .help("Swap currencies")
        .keyboardShortcut("s", modifiers: [.command, .shift])
    }

    private var rateSummary: some View {
        HStack(spacing: 16) {
            if let rate = model.rate {
                Text("1 \(model.from.displayCode) = \(model.formatRate(rate)) \(model.to.displayCode)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
            } else if let liveError = model.liveError {
                Label(liveError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text("Fetching live rate…")
                    .foregroundStyle(.secondary)
            }

            if let inverse = model.inverseRate {
                Text("1 \(model.to.displayCode) = \(model.format(inverse, for: model.from, grouping: true)) \(model.from.displayCode)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let stats = model.stats {
                HStack(spacing: 6) {
                    Image(systemName: stats.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%+.2f%%  3M", stats.changePercent))
                }
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(stats.changePercent >= 0 ? Palette.up : Palette.down)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((stats.changePercent >= 0 ? Palette.up : Palette.down).opacity(0.12), in: Capsule())
            }
        }
        .font(.callout)
    }
}
