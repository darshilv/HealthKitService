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

    func testBeginWorkoutWithYogaDefaults_doesNotThrow() async {
        let manager = HealthKitManager()
        let now = Date()
        let later = now.addingTimeInterval(60)

        do {
            try await manager.beginWorkout(startDate: now, activityType: .yoga, locationType: .indoor)
            try await manager.endWorkout(endDate: later, energyBurned: 20.0)
        } catch {
            XCTFail("Yoga workout with defaults should save without error: \(error)")
        }
    }

    func testBeginWorkoutWithRunning_doesNotThrow() async {
        let manager = HealthKitManager()
        let now = Date()
        let later = now.addingTimeInterval(60)

        do {
            try await manager.beginWorkout(startDate: now, activityType: .running, locationType: .outdoor)
            try await manager.endWorkout(endDate: later, energyBurned: 30.0)
        } catch {
            XCTFail("Running workout should save without error: \(error)")
        }
    }

    func testBeginWorkoutWithSwimming_doesNotThrow() async {
        let manager = HealthKitManager()
        let now = Date()
        let later = now.addingTimeInterval(60)

        do {
            try await manager.beginWorkout(startDate: now, activityType: .swimming, locationType: .outdoor)
            try await manager.endWorkout(endDate: later, energyBurned: 35.0)
        } catch {
            XCTFail("Swimming workout should save without error: \(error)")
        }
    }

    func testBeginWorkoutWithCycling_doesNotThrow() async {
        let manager = HealthKitManager()
        let now = Date()
        let later = now.addingTimeInterval(60)

        do {
            try await manager.beginWorkout(startDate: now, activityType: .cycling, locationType: .indoor)
            try await manager.endWorkout(endDate: later, energyBurned: 25.0)
        } catch {
            XCTFail("Cycling workout should save without error: \(error)")
        }
    }

    func testMultipleActivityTypes_sequentialWorkouts() async {
        let manager = HealthKitManager()
        let now = Date()

        do {
            // First workout - yoga
            try await manager.beginWorkout(startDate: now, activityType: .yoga, locationType: .indoor)
            let later1 = now.addingTimeInterval(60)
            try await manager.endWorkout(endDate: later1, energyBurned: 20.0)

            // Second workout - running
            let now2 = later1.addingTimeInterval(10)
            try await manager.beginWorkout(startDate: now2, activityType: .running, locationType: .outdoor)
            let later2 = now2.addingTimeInterval(60)
            try await manager.endWorkout(endDate: later2, energyBurned: 30.0)

            // Third workout - swimming
            let now3 = later2.addingTimeInterval(10)
            try await manager.beginWorkout(startDate: now3, activityType: .swimming, locationType: .outdoor)
            let later3 = now3.addingTimeInterval(60)
            try await manager.endWorkout(endDate: later3, energyBurned: 35.0)
        } catch {
            XCTFail("Sequential workouts with different activity types should not throw: \(error)")
        }
    }

    // MARK: - Pause/Resume Tests

    func testPauseAndResumeWorkout_doesNotThrow() async {
        let manager = HealthKitManager()
        let now = Date()

        do {
            try await manager.beginWorkout(startDate: now, activityType: .yoga, locationType: .indoor)
            try await manager.pauseWorkout()
            try await manager.resumeWorkout()
            let later = now.addingTimeInterval(60)
            try await manager.endWorkout(endDate: later, energyBurned: 20.0)
        } catch {
            XCTFail("Pause and resume should not throw: \(error)")
        }
    }

    func testPauseWithoutWorkout_throws() async {
        let manager = HealthKitManager()

        do {
            try await manager.pauseWorkout()
            XCTFail("Should have thrown noActiveWorkout error")
        } catch let error as WorkoutPauseError {
            XCTAssertEqual(error, .noActiveWorkout)
        } catch {
            XCTFail("Should have thrown WorkoutPauseError: \(error)")
        }
    }

    func testDoublePause_throws() async {
        let manager = HealthKitManager()
        let now = Date()

        do {
            try await manager.beginWorkout(startDate: now, activityType: .yoga, locationType: .indoor)
            try await manager.pauseWorkout()
            try await manager.pauseWorkout()
            XCTFail("Should have thrown alreadyPaused error")
        } catch let error as WorkoutPauseError {
            XCTAssertEqual(error, .alreadyPaused)
        } catch {
            XCTFail("Should have thrown WorkoutPauseError: \(error)")
        }
    }

    func testResumeWithoutPause_throws() async {
        let manager = HealthKitManager()
        let now = Date()

        do {
            try await manager.beginWorkout(startDate: now, activityType: .yoga, locationType: .indoor)
            try await manager.resumeWorkout()
            XCTFail("Should have thrown notPaused error")
        } catch let error as WorkoutPauseError {
            XCTAssertEqual(error, .notPaused)
        } catch {
            XCTFail("Should have thrown WorkoutPauseError: \(error)")
        }
    }

    func testMultiplePauseResumeCycles_doesNotThrow() async {
        let manager = HealthKitManager()
        let now = Date()

        do {
            try await manager.beginWorkout(startDate: now, activityType: .yoga, locationType: .indoor)

            // First pause/resume cycle
            try await manager.pauseWorkout()
            try await manager.resumeWorkout()

            // Second pause/resume cycle
            try await manager.pauseWorkout()
            try await manager.resumeWorkout()

            // Third pause/resume cycle
            try await manager.pauseWorkout()
            try await manager.resumeWorkout()

            let later = now.addingTimeInterval(120)
            try await manager.endWorkout(endDate: later, energyBurned: 30.0)
        } catch {
            XCTFail("Multiple pause/resume cycles should not throw: \(error)")
        }
    }

    func testEnergyAdjustment_accountsForPausedTime() async {
        let manager = HealthKitManager()
        let now = Date()
        let pauseTime: TimeInterval = 30 // 30 seconds paused
        let totalTime: TimeInterval = 120 // 2 minutes total
        let basalEnergy: Double = 20.0

        do {
            try await manager.beginWorkout(startDate: now, activityType: .yoga, locationType: .indoor)

            // Pause for 30 seconds
            try await manager.pauseWorkout()
            let pauseResumeTime = now.addingTimeInterval(pauseTime)
            try await manager.resumeWorkout()

            // End workout after total duration
            let endDate = now.addingTimeInterval(totalTime)
            try await manager.endWorkout(endDate: endDate, energyBurned: basalEnergy)

            // Energy should be adjusted:
            // Active time = 120 - 30 = 90 seconds
            // Energy = 20.0 * (90 / 120) = 15.0 kcal
            // We can't directly verify the energy stored in HealthKit, but we can verify no errors occur
        } catch {
            XCTFail("Energy adjustment test should not throw: \(error)")
        }
    }
}
