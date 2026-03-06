import Foundation

public protocol HealthKitWorkoutTracking {
    func requestAuthorization() async throws
    func beginWorkout(
        startDate: Date,
        activityType: WorkoutActivityType,
        locationType: WorkoutLocationType
    ) async throws
    func pauseWorkout() async throws
    func resumeWorkout() async throws
    func endWorkout(endDate: Date, energyBurned: Double?) async throws
}

// MARK: - Default Parameters via Protocol Extension
extension HealthKitWorkoutTracking {
    /// Convenience method with default activity type (yoga) and location (indoor)
    public func beginWorkout(startDate: Date) async throws {
        try await beginWorkout(
            startDate: startDate,
            activityType: .yoga,
            locationType: .indoor
        )
    }
}
