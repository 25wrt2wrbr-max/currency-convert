# Currency Convert

A macOS app that converts between fiat currencies and a few cryptocurrencies, with live rates and a 90-day chart.

Supported currencies: USD, PHP, GBP, EUR, RMB (CNY), JPY, CHF, BTC, ETH, SOL, and BNB.

## Build and run

```bash
make app
make run
```

That produces `dist/Currency Converter.app`. It needs macOS 14 and a Swift 6 toolchain.

Rates come from public Frankfurter, CoinGecko, and currency-api endpoints. No API key is required.
