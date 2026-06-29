import XCTest
@testable import TrackerVida

final class DomainModelTests: XCTestCase {
    func testGymHealthMockSummaries() {
        XCTAssertEqual(MockData.dailyHealthLogs.gymAttendanceCount, 4)
        XCTAssertEqual(MockData.weightLogs.latest?.weightKg, 81.8)
        XCTAssertGreaterThan(MockData.dailyHealthLogs.averageSleepHours, 7)
    }

    func testMoneySignedAmountsAndCategories() {
        let income = MockData.moneyTransactions[0]
        let expense = MockData.moneyTransactions[1]
        let transfer = MockData.moneyTransactions[2]

        XCTAssertEqual(income.signedMinorUnits, 180_000)
        XCTAssertEqual(expense.signedMinorUnits, -11_500)
        XCTAssertEqual(transfer.signedMinorUnits, 0)
        XCTAssertEqual(income.category?.label, "Trabajo")
        XCTAssertEqual(expense.category?.label, "Comida")
        XCTAssertNil(transfer.category)
    }

    func testDailyOrderCompletionRatio() {
        XCTAssertEqual(MockData.dailyOrderPlan.completionRatio, 0)
        XCTAssertEqual(MockData.dailyOrderPlan.orders.first?.checklist.count, 3)
    }
}
