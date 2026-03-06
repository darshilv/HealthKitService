import Foundation
import HealthKit
import os

// MARK: - Dependency Injection Protocols

/// Abstracts HealthKit authorization requests
protocol HealthStoreAuthorizing: AnyObject {
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws
}

/// Abstracts workout building and data collection
protocol WorkoutBuilding: AnyObject {
    func beginCollection(at startDate: Date) async throws
    func endCollection(at endDate: Date) async throws
    func addSamples(_ samples: [HKSample]) async throws
    func addWorkoutEvents(_ events: [HKWorkoutEvent]) async throws
    func finishWorkout() async throws
}

// MARK: - HealthKit Conformances

extension HKHealthStore: HealthStoreAuthorizing {}

/// Wraps HKWorkoutBuilder to provide an async/await interface conforming to WorkoutBuilding
final class LiveWorkoutBuilder: WorkoutBuilding {
    private let builder: HKWorkoutBuilder

    init(healthStore: HKHealthStore, configuration: HKWorkoutConfiguration) {
        self.builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)
    }

    func beginCollection(at startDate: Date) async throws {
        try await builder.beginCollection(at: startDate)
    }

    func endCollection(at endDate: Date) async throws {
        try await builder.endCollection(at: endDate)
    }

    func addSamples(_ samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func addWorkoutEvents(_ events: [HKWorkoutEvent]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.addWorkoutEvents(events) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func finishWorkout() async throws {
        _ = try await builder.finishWorkout()
    }
}

// MARK: - WorkoutState Enumeration
enum WorkoutState {
    case notStarted
    case active
    case paused
    case completed
}

// MARK: - Error Handling
enum WorkoutPauseError: LocalizedError, Equatable {
    case noActiveWorkout
    case alreadyPaused
    case notPaused
    case invalidPauseState

    var errorDescription: String? {
        switch self {
        case .noActiveWorkout:
            return "No active workout to pause or resume"
        case .alreadyPaused:
            return "Workout is already paused"
        case .notPaused:
            return "Workout is not currently paused"
        case .invalidPauseState:
            return "Invalid pause state transition"
        }
    }
}

public final class HealthKitManager: HealthKitWorkoutTracking {
    private let healthStore: any HealthStoreAuthorizing
    private let builderFactory: (HKWorkoutConfiguration) -> any WorkoutBuilding
    private let logger = Logger(subsystem: "com.healthkit.manager", category: "HealthKitManager")
    private var builder: (any WorkoutBuilding)?
    private var workoutStartDate: Date?

    // State tracking for pause/resume functionality
    private var workoutState: WorkoutState = .notStarted
    private var isPaused: Bool = false
    private var pausedStartDate: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var pauseResumeHistory: [(pauseTime: Date, resumeTime: Date?)] = []

    public init(
        healthStore: any HealthStoreAuthorizing = HKHealthStore(),
        builderFactory: ((HKWorkoutConfiguration) -> any WorkoutBuilding)? = nil
    ) {
        self.healthStore = healthStore
        self.builderFactory = builderFactory ?? { config in
            LiveWorkoutBuilder(healthStore: HKHealthStore(), configuration: config)
        }
    }

    public func requestAuthorization() async throws {
        let typesToShare: Set = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: [])
    }

    public func beginWorkout(
        startDate: Date,
        activityType: WorkoutActivityType = .yoga,
        locationType: WorkoutLocationType = .indoor
    ) async throws {
        let emoji = getEmojiForActivityType(activityType)
        logger.info("\(emoji) HealthKitManager.beginWorkout at \(startDate)")

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType.hkActivityType
        configuration.locationType = locationType.hkLocationType

        let builder = builderFactory(configuration)
        try await builder.beginCollection(at: startDate)

        self.builder = builder
        self.workoutStartDate = startDate

        // Reset pause/resume state for new workout
        self.workoutState = .active
        self.isPaused = false
        self.pausedStartDate = nil
        self.totalPausedDuration = 0
        self.pauseResumeHistory = []
    }

    public func pauseWorkout() async throws {
        guard builder != nil else {
            throw WorkoutPauseError.noActiveWorkout
        }

        guard workoutState == .active else {
            throw WorkoutPauseError.alreadyPaused
        }

        let now = Date()
        pausedStartDate = now
        workoutState = .paused
        isPaused = true
        logger.info("⏸ Workout paused at \(now)")
    }

    public func resumeWorkout() async throws {
        guard builder != nil else {
            throw WorkoutPauseError.noActiveWorkout
        }

        guard workoutState == .paused else {
            throw WorkoutPauseError.notPaused
        }

        guard let pausedStartDate = pausedStartDate else {
            throw WorkoutPauseError.invalidPauseState
        }

        let now = Date()
        let pausedDuration = now.timeIntervalSince(pausedStartDate)
        totalPausedDuration += pausedDuration
        pauseResumeHistory.append((pauseTime: pausedStartDate, resumeTime: now))
        self.pausedStartDate = nil

        workoutState = .active
        isPaused = false
        logger.info("▶️ Workout resumed at \(now) after \(pausedDuration)s pause")
    }

    public func endWorkout(endDate: Date, energyBurned: Double?) async throws {
        logger.info("🏁 HealthKitManager.endWorkout at \(endDate), energy: \(energyBurned ?? -1)")

        guard let builder = builder else { return }

        try await builder.endCollection(at: endDate)

        // Add pause/resume events to the workout
        if !pauseResumeHistory.isEmpty {
            var workoutEvents: [HKWorkoutEvent] = []
            for (pauseTime, resumeTime) in pauseResumeHistory {
                workoutEvents.append(HKWorkoutEvent(type: .pause, date: pauseTime))
                if let resumeTime = resumeTime {
                    workoutEvents.append(HKWorkoutEvent(type: .resume, date: resumeTime))
                }
            }
            try await builder.addWorkoutEvents(workoutEvents)
        }

        if let kcal = energyBurned {
            // Calculate adjusted energy accounting for paused time
            var finalEnergy = kcal

            // If there was paused time, adjust energy proportionally
            if totalPausedDuration > 0, let startDate = workoutStartDate {
                let totalDuration = endDate.timeIntervalSince(startDate)
                let activeDuration = totalDuration - totalPausedDuration
                if totalDuration > 0 {
                    finalEnergy = kcal * (activeDuration / totalDuration)
                }
            }

            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: finalEnergy),
                start: workoutStartDate ?? endDate,
                end: endDate
            )
            try await builder.addSamples([energySample])
        }

        try await builder.finishWorkout()
        self.builder = nil

        self.workoutStartDate = nil

        // Reset pause/resume tracking state
        self.workoutState = .completed
        self.isPaused = false
        self.pausedStartDate = nil
        self.totalPausedDuration = 0
        self.pauseResumeHistory = []
    }

    // MARK: - Helper Methods

    private func getEmojiForActivityType(_ type: WorkoutActivityType) -> String {
        switch type {
        case .yoga:
            return "🧘"
        case .running:
            return "🏃"
        case .cycling:
            return "🚴"
        case .swimming:
            return "🏊"
        case .walking:
            return "🚶"
        case .elliptical:
            return "🏋️"
        case .rowing:
            return "🚣"
        case .hiking:
            return "⛰️"
        case .other:
            return "💪"
        }
    }
}
