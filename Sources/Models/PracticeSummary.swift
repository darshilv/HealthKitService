import Foundation

public struct PracticeSummary {
    public let startDate: Date
    public let endDate: Date
    public let energyBurnedInKcal: Double?

    public init(startDate: Date, endDate: Date, energyBurnedInKcal: Double?) {
        self.startDate = startDate
        self.endDate = endDate
        self.energyBurnedInKcal = energyBurnedInKcal
    }
}
