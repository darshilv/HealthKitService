import Foundation
import HealthKit
import os

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
    private let healthStore = HKHealthStore()
    private let logger = Logger(subsystem: "com.healthkit.manager", category: "HealthKitManager")
    private var builder: HKWorkoutBuilder?
    private var workoutStartDate: Date?

    // State tracking for pause/resume functionality
    private var workoutState: WorkoutState = .notStarted
    private var isPaused: Bool = false
    private var pausedStartDate: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var pauseResumeHistory: [(pauseTime: Date, resumeTime: Date?)] = []

    public init() {}

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

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)
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
            try await addWorkoutEventsAsync(workoutEvents, to: builder)
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
            try await addSampleAsync(energySample, to: builder)
        }

        _ = try await builder.finishWorkout()
        self.builder = nil
        self.workoutStartDate = nil

        // Reset pause/resume tracking state
        self.workoutState = .completed
        self.isPaused = false
        self.pausedStartDate = nil
        self.totalPausedDuration = 0
        self.pauseResumeHistory = []
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

    private func addWorkoutEventsAsync(_ events: [HKWorkoutEvent], to builder: HKWorkoutBuilder) async throws {
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
