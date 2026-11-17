import XCTest
@testable import AccountingCore

final class CoreTests: XCTestCase {

    // Money
    func testEuroAmounts() {
        XCTAssertEqual(MoneyParser.minorUnits("1.234,56 €"), 123456)
        XCTAssertEqual(MoneyParser.minorUnits("-1.234,56"), -123456)
        XCTAssertEqual(MoneyParser.minorUnits("1,234.56"), 123456)
        XCTAssertEqual(MoneyParser.minorUnits("45,1"), 4510)
        XCTAssertEqual(MoneyParser.minorUnits("1.234"), 123400)
        XCTAssertEqual(MoneyParser.minorUnits("(7,50)"), -750)
        XCTAssertNil(MoneyParser.minorUnits("n/a"))

        XCTAssertEqual(MoneyParser.minorUnits("3.910000", format: .dotDecimal), 391)
        XCTAssertEqual(MoneyParser.minorUnits("-200.000000", format: .dotDecimal), -20000)
    }

    // CSV
    func testQuotedCSV() {
        let csv = "Datum;Betrag;Text\r\n01.01.2026;\"-23,40\";\"Hallo; \"\"Welt\"\"\"\r\n"
        let rows = CSVReader.rows(csv)

        XCTAssertEqual(rows.count, 2)
        guard rows.count > 1, rows[1].count > 2 else { return }
        XCTAssertEqual(rows[1][2], "Hallo; \"Welt\"")
    }

    func testMinimalCommaDelimitedAndBankPreamble() throws {
        let twoColumns = "date,amount\n2026-10-02,3.910000\n"
        let broker = try CSVImportMapper.parse(Data(twoColumns.utf8), institution: .broker, accountKey: "minimal")
        XCTAssertEqual(broker.records.first?.amountMinor, 391)

        let bank = "Export vom 01.11.2026\nKonto: Demo\nBuchungstag;Betrag;Waehrung\n02.10.2026;-15,20;EUR\n"
        let checking = try CSVImportMapper.parse(Data(bank.utf8), institution: .bank, accountKey: "test")
        XCTAssertEqual(checking.records.first?.amountMinor, -1520)
    }

    func testInvalidRowsFlagged() throws {
        let csv = "Datum;Betrag;Währung\n01.10.2026;23,00;USD\nfoo;5,00;EUR\n"
        let parsed = try CSVImportMapper.parse(Data(csv.utf8), institution: .other, accountKey: "a")

        XCTAssertEqual(parsed.records.count, 0)
        XCTAssertEqual(parsed.issues.count, 2)
    }

    // Bank export
    func testBankSampleAndDuplicates() throws {
        let csv = """
        Buchungstag;Betrag;Beguenstigter/Zahlungspflichtiger;Verwendungszweck;Waehrung
        01.10.2026;-12,50;REWE;Lebensmittel;EUR
        01.10.2026;-12,50;REWE;Lebensmittel;EUR

        """
        let parsed = try CSVImportMapper.parse(Data(csv.utf8), institution: .bank, accountKey: "checking")

        XCTAssertEqual(parsed.records.count, 2)
        XCTAssertEqual(parsed.records.first?.category, "Groceries")
        XCTAssertNotEqual(parsed.records[0].dedupKey, parsed.records[1].dedupKey)

        // same file twice has to give the same keys
        let parsedAgain = try CSVImportMapper.parse(Data(csv.utf8), institution: .bank, accountKey: "checking")
        XCTAssertEqual(parsedAgain.records.map(\.dedupKey), parsed.records.map(\.dedupKey))
    }

    // Broker export
    func testBrokerTradeType() throws {
        let csv = """
        date,transaction_id,type,amount,currency,name,description
        2026-10-01,abc-123,BUY,-100.00,EUR,ETF,Investment
        2026-10-02,abc-124,DIVIDEND,3.91,EUR,ETF,Dividend

        """
        let parsed = try CSVImportMapper.parse(Data(csv.utf8), institution: .broker, accountKey: "portfolio")
        XCTAssertEqual(parsed.records.map(\.kind), [.investmentBuy, .dividend])

        let totals = FinanceAnalytics.summary(parsed.records)
        XCTAssertEqual(totals.incomeMinor, 391)
        XCTAssertEqual(totals.expenseMinor, 0)
    }

    func testBrokerFixedDecimalsAndUnconfirmedTransfer() throws {
        let csv = """
        date,transaction_id,type,amount,currency,name,description
        2026-10-01,id-1,BUY,-200.000000,EUR,ETF,Kauf
        2026-10-02,id-2,DIVIDEND,3.910000,EUR,ETF,Dividende
        2026-10-03,id-3,TRANSFER,100.000000,EUR,Depot,Einzahlung

        """
        let result = try CSVImportMapper.parse(Data(csv.utf8), institution: .broker, accountKey: "broker")

        XCTAssertEqual(result.records.map(\.amountMinor), [-20000, 391, 10000])
        XCTAssertEqual(result.records[2].kind, .unknown)
        XCTAssertEqual(FinanceAnalytics.summary(result.records).incomeMinor, 391)
    }

    // Cashflow
    func testInternalTransferExcludedFromIncomeExpense() {
        let date = BookingDateParser.parse("2026-10-01")!
        let rows: [TransactionRecord] = [
            .init(bookedAt: date, amountMinor: -10000, merchant: "Transfer", memo: "", kind: .transfer, category: "Transfers"),
            .init(bookedAt: date, amountMinor: 10000, merchant: "Transfer", memo: "", kind: .transfer, category: "Transfers"),
            .init(bookedAt: date, amountMinor: 250000, merchant: "Salary", memo: "", kind: .income, category: "Salary"),
            .init(bookedAt: date, amountMinor: -35000, merchant: "Rent", memo: "", kind: .expense, category: "Housing")
        ]
        let summary = FinanceAnalytics.summary(rows)

        XCTAssertEqual(summary.incomeMinor, 250000)
        XCTAssertEqual(summary.expenseMinor, 35000)
        XCTAssertEqual(summary.netMinor, 215000)
    }

    func testMonthBucketsIgnoreTrades() {
        let october = BookingDateParser.parse("2026-10-15")!
        let november = BookingDateParser.parse("2026-11-02")!
        let rows: [TransactionRecord] = [
            .init(bookedAt: november, amountMinor: -4000, merchant: "REWE", memo: "", kind: .expense, category: "Groceries"),
            .init(bookedAt: october, amountMinor: 250000, merchant: "Salary", memo: "", kind: .income, category: "Salary"),
            .init(bookedAt: october, amountMinor: -20000, merchant: "ETF", memo: "", kind: .investmentBuy, category: "Investments")
        ]
        let buckets = FinanceAnalytics.months(rows)

        XCTAssertEqual(buckets.map(\.id), ["2026-10", "2026-11"])
        XCTAssertEqual(buckets[0].expenseMinor, 0)
        XCTAssertEqual(buckets[1].expenseMinor, 4000)
    }

    // Transfers
    func testTransferSuggestionsRequireOtherAccountAndOppositeSign() {
        let date = BookingDateParser.parse("2026-10-01")!
        let accountA = UUID()
        let accountB = UUID()
        let source = TransactionRecord(bookedAt: date, amountMinor: -5000, merchant: "Transfer", memo: "", kind: .expense, category: "Other")
        let opposite = TransactionRecord(bookedAt: date, amountMinor: 5000, merchant: "Transfer", memo: "", kind: .income, category: "Other")

        let candidates = TransferMatching.candidates(
            source: source,
            sourceAccount: accountA,
            others: [(accountA, opposite), (accountB, opposite)]
        )
        XCTAssertEqual(candidates.count, 1)
    }
}
