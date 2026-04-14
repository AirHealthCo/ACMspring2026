//
//  WaterModels.swift
//  ACMspring2026
//

import Foundation

struct WaterLog: Codable {
    var entries: [WaterEntry]
    var dailyGoalMl: Double
    var lastResetDate: Date
    var unitPreference: WaterUnit

    var totalTodayMl: Double {
        entries.reduce(0) { $0 + $1.amountMl }
    }

    var fillFraction: Double {
        guard dailyGoalMl > 0 else { return 0 }
        return min(totalTodayMl / dailyGoalMl, 1.0)
    }
}

struct WaterEntry: Codable, Identifiable {
    let id: UUID
    let amountMl: Double
    let timestamp: Date
}

enum WaterUnit: String, Codable, CaseIterable {
    case ml, cups

    var label: String { self == .ml ? "mL" : "cups" }

    func fromMl(_ ml: Double) -> Double {
        self == .ml ? ml : ml / 236.588
    }

    func toMl(_ value: Double) -> Double {
        self == .ml ? value : value * 236.588
    }

    func format(_ ml: Double) -> String {
        let value = fromMl(ml)
        switch self {
        case .ml:
            return "\(Int(value.rounded())) mL"
        case .cups:
            let formatted = value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))"
                : String(format: "%.1f", value)
            return "\(formatted) \(value == 1.0 ? "cup" : "cups")"
        }
    }
}
