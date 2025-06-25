import XCTest
@testable import HealthKitService

final class HealthKitManagerTests: XCTestCase {
    func testBeginAndEndWorkout_doesNotThrow() async {
        let manager = HealthKitManager()
        let now = Date()
        let later = now.addingTimeInterval(60)

        do {
            try await manager.beginWorkout(startDate: now)
            try await manager.endWorkout(endDate: later, energyBurned: 20.0)
        } catch {
            XCTFail("Workout should save without error: \(error)")
        }
    }
}
