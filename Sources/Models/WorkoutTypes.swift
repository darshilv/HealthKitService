import HealthKit

public enum WorkoutActivityType {
    case yoga
    case running
    case cycling
    case swimming
    case walking
    case elliptical
    case rowing
    case hiking
    case other

    public var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .yoga:       return .yoga
        case .running:    return .running
        case .cycling:    return .cycling
        case .swimming:   return .swimming
        case .walking:    return .walking
        case .elliptical: return .elliptical
        case .rowing:     return .rowing
        case .hiking:     return .hiking
        case .other:      return .other
        }
    }
}

public enum WorkoutLocationType {
    case indoor
    case outdoor
    case unknown

    public var hkLocationType: HKWorkoutSessionLocationType {
        switch self {
        case .indoor:  return .indoor
        case .outdoor: return .outdoor
        case .unknown: return .unknown
        }
    }
}
