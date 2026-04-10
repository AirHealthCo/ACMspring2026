//
//  FoodInformation.swift
//  ACMspring2026
//
//  Created by Ruthvik Penubarthi on 3/10/26.
//
import SwiftUI

struct FoodInformationView: View {
    let name: String
    let usdaQuery: String
    let dataType: String
    @State private var foodData: NutritionInfo?

    var body: some View {
        VStack {
            if let food = foodData {
                Text(food.foodName)
                Text("Serving size: \(String(format: "%.0f", food.servingSizeG ?? 100)) g")
                Text("Calories: \(food.caloriesKcal.map { String(format: "%.1f", $0) } ?? "—")")
                Text("Protein: \(food.proteinG.map { String(format: "%.1f", $0) } ?? "—") g")
                Text("Carbs: \(food.totalCarbsG.map { String(format: "%.1f", $0) } ?? "—") g")
                Text("Fat: \(food.totalFatG.map { String(format: "%.1f", $0) } ?? "—") g")
            } else {
                Text("Loading...")
            }
        }.task {
            if !usdaQuery.isEmpty {
                foodData = try? await NutritionAPI.shared.getNutrition(for: usdaQuery, dataType: dataType)
            }
        }
    }

    
    
}

#Preview {
    FoodInformationView(name: "Apple", usdaQuery: "apple raw", dataType: "Foundation")
}


