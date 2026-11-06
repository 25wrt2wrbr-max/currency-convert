import SwiftUI

struct AmountCard: View {
    let side: Side
    @Bindable var model: ConverterViewModel
    @FocusState private var focused: Bool

    private var currency: Currency {
        side == .from ? model.from : model.to
    }

    private var amountText: Binding<String> {
        Binding(
            get: { side == .from ? model.fromText : model.toText },
            set: { model.edit(side, text: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(side == .from ? "You send" : "You get")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                CurrencyPicker(selection: currency) { picked in
                    if side == .from {
                        model.setFrom(picked)
                    } else {
                        model.setTo(picked)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currency.symbol)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(currency.tint)
                    .frame(minWidth: 28, alignment: .leading)
                TextField("0", text: amountText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .focused($focused)
                    .onSubmit { model.applyRate() }
            }

            HStack {
                Text(currency.name)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if side == .from {
                    HStack(spacing: 6) {
                        ForEach([1.0, 10, 100, 1_000], id: \.self) { chip in
                            Button(chipLabel(chip)) {
                                model.applyQuickAmount(chip)
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.5), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous)
                .strokeBorder(focused ? currency.tint.opacity(0.55) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous)
                    .fill(currency.tint.opacity(0.08))
            )
    }

    private func chipLabel(_ value: Double) -> String {
        value >= 1000 ? "1k" : String(Int(value))
    }
}

struct CurrencyPicker: View {
    let selection: Currency
    var onPick: (Currency) -> Void
    @State private var open = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            HStack(spacing: 8) {
                CurrencyGlyph(currency: selection, size: 26)
                Text(selection.displayCode)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .monospaced()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.45), in: Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Currency.allCases) { currency in
                    Button {
                        onPick(currency)
                        open = false
                    } label: {
                        HStack(spacing: 8) {
                            CurrencyGlyph(currency: currency, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(currency.displayCode)
                                    .font(.subheadline.weight(.semibold))
                                    .monospaced()
                                Text(currency.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if currency == selection {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(currency == selection ? currency.tint.opacity(0.14) : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(width: 360)
        }
        .help("Choose \(selection.name)")
    }
}

struct CurrencyGlyph: View {
    let currency: Currency
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(currency.tint.opacity(currency.usesEmojiBadge ? 0.18 : 1))
            if currency.usesEmojiBadge {
                Text(currency.badge)
                    .font(.system(size: size * 0.52))
            } else {
                Text(currency.badge)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }
}
