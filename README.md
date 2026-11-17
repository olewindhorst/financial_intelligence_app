# Financial Intelligence App

A small offline iPhone app for your personal finances. You import CSV exports from your bank and your broker, the app sorts the bookings into categories and shows your monthly cashflow.

```text
CSV export -> import -> kind + category -> monthly cashflow and budgets
```

Your data stays on your phone. There is no server, no bank login and no iCloud sync.

## Features

- Separate accounts for bank, broker or other providers
- CSV import from the Files app, with import history and duplicate check
- Search and filter bookings, change kind and category by hand
- Link a transfer between two of your own accounts
- Monthly income, expenses, savings rate and a six month chart
- Monthly budgets per category
- CSV export and an optional Face ID lock
- Demo data so you can try the app without real bookings

## Structure

```text
├── project.yml        # XcodeGen project definition
├── Config/            # signing settings
├── Core/              # Swift package with parser, rules and calculations
├── iOS/               # SwiftUI app (views, SwiftData models, import/export)
├── Samples/           # two synthetic CSV files for testing
└── scripts/
```

The calculation logic lives in `Core` and has no iOS dependency, so you can test it on its own.

## Import

The importer looks for the header row in the first 40 lines of your file and matches the columns by name. German and English column names are supported.

| Field | Recognised column names (examples) |
| --- | --- |
| Date | `Buchungstag`, `Datum`, `date`, `booking_date` |
| Amount | `Betrag`, `Umsatz`, `amount`, `cash_amount` |
| Merchant | `Beguenstigter/Zahlungspflichtiger`, `Empfänger`, `name` |
| Purpose | `Verwendungszweck`, `Buchungstext`, `description` |
| Currency | `Waehrung`, `Währung`, `currency` |
| Type | `type`, `Buchungsart` |
| ID | `transaction_id`, `Umsatz-ID` |

Date and amount are required, the rest is optional. Only EUR rows are imported. Rows that can't be read are listed with their line number in the import history.

If your export uses another column name, add it to the alias lists in `Core/Sources/AccountingCore/CSVImportMapper.swift`.

Duplicates are checked per account:

```text
with ID:    provider + account + transaction ID
without ID: provider + account + date + amount + merchant + purpose + type + counter
```

The counter keeps two identical bookings on the same day. Overlapping exports without IDs can still slip through, so take a quick look at the import history after each import.

## Calculation

Amounts are stored as whole cents (`Int64`), not as floating point numbers.

```text
income   = sum of positive bookings
expenses = sum of negative bookings
net      = income - expenses
savings  = net / income
```

Only income, expenses, dividends, interest, fees and taxes count. Buying or selling securities and confirmed transfers between your own accounts are left out.

A plain `TRANSFER` from a broker export is set to "Unclear" on purpose. It only counts as a transfer once you link it to the matching booking on your other account.

## Run on your iPhone

You need once:

- Xcode from the Mac App Store
- XcodeGen: `brew install xcodegen`
- an Apple ID added in Xcode (Settings → Accounts)

Set up signing:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Enter your own bundle id and team id in `Config/Local.xcconfig`. The file is ignored by git, so your signing data never ends up in the repo.

Build:

```bash
xcodegen generate
open Accounting.xcodeproj
```

Connect your iPhone, select it as run destination and press Run. On the first start your iPhone asks you to enable the developer mode (Settings → Privacy & Security) and to trust the developer profile (Settings → General → VPN & Device Management).

With a free Apple ID you have to install the app again from Xcode every 7 days. A paid developer account removes this limit.

## Run on your Mac

Without an iPhone you can use the simulator: pick any iPhone model as run destination in Xcode and press Run. To test the import, drag a CSV file from `Samples/` onto the simulator window, it ends up in the Files app.

On a Mac with Apple Silicon you can also pick "My Mac (Designed for iPhone)" as run destination.

## Tests

The `Core` package has XCTest tests for amounts, CSV parsing, bank and broker formats, duplicates and cashflow.

```bash
./scripts/check_core.sh
```

## Samples

[`Samples/bank_demo.csv`](Samples/bank_demo.csv) and [`Samples/broker_demo.csv`](Samples/broker_demo.csv) are synthetic. They show a typical German bank export (semicolons, decimal commas) and a typical broker export (commas, fixed decimals). Real exports can have other columns.

Keep your real exports in a `private/` folder, it is ignored by git.

## Limits

- No automatic bank sync, no PDF or XLSX import
- EUR only
- No account balances or portfolio values, only cashflow
- Fees and taxes inside a broker trade are not split out
- Categories come from simple keyword rules
- iOS backups of your phone can still contain the data

## License

MIT, see [LICENSE](LICENSE).
