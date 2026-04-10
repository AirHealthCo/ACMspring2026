//
//  WaterLogView.swift
//  ACMspring2026
//

import SwiftUI

struct WaterLogView: View {
    @EnvironmentObject var store: WaterStore
    @Environment(\.dismiss) private var dismiss
    @State private var customText = ""
    @State private var goalText = ""

    private var unit: WaterUnit { store.log.unitPreference }

    private var sortedEntries: [WaterEntry] {
        store.log.entries.sorted { $0.timestamp > $1.timestamp }
    }

    private var quickAmounts: [(label: String, ml: Double)] {
        switch unit {
        case .ml:
            return [("250 mL", 250), ("500 mL", 500), ("750 mL", 750)]
        case .cups:
            return [("½ cup", 118.294), ("1 cup", 236.588), ("2 cups", 473.176)]
        }
    }

    var body: some View {
        List {
            // Unit toggle
            Section {
                Picker("Unit", selection: Binding(
                    get: { store.log.unitPreference },
                    set: { newUnit in
                        store.setUnit(newUnit)
                        goalText = formatGoalText(for: newUnit)
                    }
                )) {
                    Text("mL").tag(WaterUnit.ml)
                    Text("cups").tag(WaterUnit.cups)
                }
                .pickerStyle(.segmented)
            }

            // Progress ring
            Section {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: store.log.fillFraction)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: store.log.fillFraction)
                    VStack(spacing: 4) {
                        Text(unit.format(store.log.totalTodayMl))
                            .font(.title2.bold())
                        Text("of \(unit.format(store.log.dailyGoalMl))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 160, height: 160)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Quick add
            Section("Quick Add") {
                HStack(spacing: 10) {
                    ForEach(quickAmounts, id: \.label) { item in
                        Button(item.label) {
                            store.addEntry(amountMl: item.ml)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
            }

            // Custom entry
            Section("Custom") {
                HStack {
                    TextField("Amount (\(unit.label))", text: $customText)
                        .keyboardType(.decimalPad)
                    Button("Add") {
                        if let value = Double(customText), value > 0 {
                            store.addEntry(amountMl: unit.toMl(value))
                            customText = ""
                        }
                    }
                    .disabled(Double(customText) == nil)
                }
            }

            // Today's log
            Section("Today's Log") {
                if sortedEntries.isEmpty {
                    Text("No entries yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedEntries) { entry in
                        HStack {
                            Text(entry.timestamp, style: .time)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(unit.format(entry.amountMl))
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            store.removeEntry(id: sortedEntries[i].id)
                        }
                    }
                }
            }

            // Daily goal
            Section("Daily Goal") {
                HStack {
                    TextField("Goal", text: $goalText)
                        .keyboardType(.decimalPad)
                        .onSubmit { commitGoal() }
                    Text(unit.label)
                        .foregroundStyle(.secondary)
                }
            }

            // Debug
            Section("Debug") {
                HStack(spacing: 10) {
                    ForEach(quickAmounts, id: \.label) { item in
                        Button("−\(item.label)") {
                            store.removeWater(amountMl: item.ml)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
                Button("Clear All", role: .destructive) {
                    store.clearAllEntries()
                }
            }
        }
        .navigationTitle("Water Intake")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            store.resetIfNewDay()
            goalText = formatGoalText(for: unit)
        }
    }

    private func formatGoalText(for unit: WaterUnit) -> String {
        let value = unit.fromMl(store.log.dailyGoalMl)
        if unit == .ml {
            return "\(Int(value.rounded()))"
        } else {
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))"
                : String(format: "%.1f", value)
        }
    }

    private func commitGoal() {
        if let value = Double(goalText), value > 0 {
            store.setGoal(amountMl: unit.toMl(value))
        } else {
            goalText = formatGoalText(for: unit)
        }
    }
}

#Preview {
    NavigationStack {
        WaterLogView()
    }
    .environmentObject(WaterStore())
}
