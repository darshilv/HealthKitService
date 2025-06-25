import Foundation

public protocol HealthKitWorkoutTracking {
    func requestAuthorization() async throws
    func beginWorkout(startDate: Date) async throws
    func pauseWorkout() async throws
    func resumeWorkout() async throws
    func endWorkout(endDate: Date, energyBurned: Double?) async throws
}
