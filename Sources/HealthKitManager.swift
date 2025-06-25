import Foundation
import HealthKit

public final class HealthKitManager: HealthKitWorkoutTracking {
    private let healthStore = HKHealthStore()
    private var builder: HKWorkoutBuilder?
    private var workoutStartDate: Date?

    public init() {}

    public func requestAuthorization() async throws {
        let typesToShare: Set = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: [])
    }

    public func beginWorkout(startDate: Date) async throws {
        print("🧘‍♀️ HealthKitManager.beginWorkout at \(startDate)")
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .yoga
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)
        try await builder.beginCollection(at: startDate)

        self.builder = builder
        self.workoutStartDate = startDate
    }

    public func pauseWorkout() async throws {}

    public func resumeWorkout() async throws {}

    public func endWorkout(endDate: Date, energyBurned: Double?) async throws {
        print("🏁 HealthKitManager.endWorkout at \(endDate), energy: \(energyBurned ?? -1)")
        guard let builder = builder else { return }

        try await builder.endCollection(at: endDate)

        if let kcal = energyBurned {
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: workoutStartDate ?? endDate,
                end: endDate
            )
            try await addSampleAsync(energySample, to: builder)
        }

        _ = try await builder.finishWorkout()
        self.builder = nil
        self.workoutStartDate = nil
    }
    
    private func addSampleAsync(_ sample: HKSample, to builder: HKWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add([sample]) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
