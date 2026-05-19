//
//  WaterStore.swift
//  ACMspring2026
//

import Foundation

class WaterStore: ObservableObject {
    @Published var log: WaterLog

    private let defaultsKey = "waterLog"

    init() {
        if let data = UserDefaults.standard.data(forKey: "waterLog"),
           let saved = try? JSONDecoder().decode(WaterLog.self, from: data) {
            log = saved
        } else {
            log = WaterLog(
                entries: [],
                dailyGoalMl: 2000,
                lastResetDate: Date(),
                unitPreference: .ml
            )
        }
        resetIfNewDay()
    }

    func addEntry(amountMl: Double) {
        log.entries.append(WaterEntry(id: UUID(), amountMl: amountMl, timestamp: Date()))
        persist()
    }

    func removeEntry(id: UUID) {
        log.entries.removeAll { $0.id == id }
        persist()
    }

    func setUnit(_ unit: WaterUnit) {
        log.unitPreference = unit
        persist()
    }

    func setGoal(amountMl: Double) {
        log.dailyGoalMl = amountMl
        persist()
    }

    func removeWater(amountMl: Double) {
        let target = max(log.totalTodayMl - amountMl, 0)
        log.entries = []
        if target > 0 {
            log.entries.append(WaterEntry(id: UUID(), amountMl: target, timestamp: Date()))
        }
        persist()
    }

    func clearAllEntries() {
        log.entries = []
        persist()
    }

    func resetIfNewDay() {
        if !Calendar.current.isDateInToday(log.lastResetDate) {
            log.entries = []
            log.lastResetDate = Date()
            persist()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(log) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
