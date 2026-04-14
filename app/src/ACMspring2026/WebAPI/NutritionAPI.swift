// NutritionAPI.swift
// Swift port of api/nutrition_api.py
//
// Provides two async functions mirroring the Python FastAPI routes:
//   NutritionAPI.shared.getNutrition(for:)   → /nutrition/{food_name}
//   NutritionAPI.shared.getFoodInsights(for:) → /food-insights/{food_name}
//
// Both API keys are read from Secrets.plist (USDA_API_KEY, ANTHROPIC_API_KEY).

import Foundation

// MARK: - Models

struct NutritionInfo: Codable {
    var foodName:       String
    var servingSizeG:   Double?
    var caloriesKcal:   Double?
    var totalFatG:      Double?
    var saturatedFatG:  Double?
    var transFatG:      Double?
    var cholesterolMg:  Double?
    var sodiumMg:       Double?
    var totalCarbsG:    Double?
    var dietaryFiberG:  Double?
    var totalSugarsG:   Double?
    var proteinG:       Double?
    var vitaminDMcg:    Double?
    var calciumMg:      Double?
    var ironMg:         Double?
    var potassiumMg:    Double?
}

struct FoodInsights: Codable {
    var foodName: String
    var pairings: [String]
    var risks:    [String]
    var benefits: [String]
}

// MARK: - Errors

enum NutritionAPIError: Error {
    case missingAPIKey(String)
    case httpError(Int)
    case noResults
    case invalidJSON
}

// MARK: - USDA response shapes (private)

private struct USDASearchResponse: Decodable {
    let foods: [USDAFood]
}

private struct USDAFood: Decodable {
    let description:   String
    let servingSize:   Double?
    let foodNutrients: [USDANutrient]
}

private struct USDANutrient: Decodable {
    let nutrientName: String
    let unitName:     String?
    let value:        Double?
}

// MARK: - Nutrient name → NutritionInfo key-path map (mirrors Python NUTRIENT_MAP)

private let nutrientMap: [String: WritableKeyPath<NutritionInfo, Double?>] = [
    "Energy":                                    \.caloriesKcal,
    "Energy (Atwater General Factors)":          \.caloriesKcal,
    "Energy (Atwater Specific Factors)":         \.caloriesKcal,
    "Total lipid (fat)":                   \.totalFatG,
    "Fatty acids, total saturated":        \.saturatedFatG,
    "Fatty acids, total trans":            \.transFatG,
    "Cholesterol":                         \.cholesterolMg,
    "Sodium, Na":                          \.sodiumMg,
    "Carbohydrate, by difference":         \.totalCarbsG,
    "Fiber, total dietary":                \.dietaryFiberG,
    "Sugars, total including NLEA":        \.totalSugarsG,
    "Total Sugars":                        \.totalSugarsG,
    "Protein":                             \.proteinG,
    "Vitamin D (D2 + D3)":                 \.vitaminDMcg,
    "Calcium, Ca":                         \.calciumMg,
    "Iron, Fe":                            \.ironMg,
    "Potassium, K":                        \.potassiumMg,
]

private func parseNutrients(from food: USDAFood) -> NutritionInfo {
    let simpleName = food.description
        .components(separatedBy: ",").first?
        .trimmingCharacters(in: .whitespaces) ?? food.description
    var info = NutritionInfo(foodName: simpleName, servingSizeG: food.servingSize)
    for nutrient in food.foodNutrients {
        guard let kp = nutrientMap[nutrient.nutrientName],
              info[keyPath: kp] == nil,   // first match wins
              let value = nutrient.value
        else { continue }
        // Skip kJ energy entries — only accept KCAL
        if nutrient.nutrientName == "Energy",
           nutrient.unitName?.uppercased() != "KCAL" { continue }
        info[keyPath: kp] = value
    }
    return info
}

// MARK: - NutritionAPI actor

actor NutritionAPI {
    static let shared = NutritionAPI()

    private let usdaSearchURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    private let claudeURL     = URL(string: "https://api.anthropic.com/v1/messages")!

    private let usdaAPIKey: String = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key  = dict["USDA_API_KEY"] as? String
        else { fatalError("Missing USDA_API_KEY in Secrets.plist") }
        return key
    }()

    private let anthropicAPIKey: String = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key  = dict["ANTHROPIC_API_KEY"] as? String
        else { fatalError("Missing ANTHROPIC_API_KEY in Secrets.plist") }
        return key
    }()

    // Mirrors: GET /nutrition/{food_name}
    func getNutrition(for foodName: String, dataType: String = "Foundation") async throws -> NutritionInfo {
        var components = URLComponents(string: usdaSearchURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key",  value: usdaAPIKey),
            URLQueryItem(name: "query",    value: foodName),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "dataType", value: dataType),
        ]

        print("[USDA] Searching for '\(foodName)' ...")

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("[USDA] HTTP error: \(http.statusCode)")
            throw NutritionAPIError.httpError(http.statusCode)
        }

        print("[USDA] Raw response:\n\(String(data: data, encoding: .utf8) ?? "<unreadable>")")

        let decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        guard let first = decoded.foods.first else {
            print("[USDA] No results for '\(foodName)'")
            throw NutritionAPIError.noResults
        }

        print("[USDA] All nutrients for '\(first.description)':")
        for n in first.foodNutrients {
            print("  \(n.nutrientName) (\(n.unitName ?? "?")): \(n.value.map { String($0) } ?? "nil")")
        }

        let result = parseNutrients(from: first)
        print("[USDA] Final decision → \(result.foodName)")
        print("  calories: \(result.caloriesKcal.map { "\($0) kcal" } ?? "nil")")
        print("  protein:  \(result.proteinG.map { "\($0) g" } ?? "nil")")
        print("  carbs:    \(result.totalCarbsG.map { "\($0) g" } ?? "nil")")
        print("  fat:      \(result.totalFatG.map { "\($0) g" } ?? "nil")")
        return result
    }

    // Mirrors: GET /food-insights/{food_name}
    func getFoodInsights(for foodName: String) async throws -> FoodInsights {
        let prompt = """
        Provide factual nutritional insights about "\(foodName)".
        Return ONLY valid JSON with exactly these three keys (no markdown, no explanation):
        {
          "pairings": ["<5 foods that pair well with \(foodName), each ≤12 words>"],
          "risks": ["<3-5 health risks or dietary concerns, each ≤20 words>"],
          "benefits": ["<3-5 health benefits, each ≤20 words>"]
        }
        """

        let body: [String: Any] = [
            "model":      "claude-sonnet-4-6",
            "max_tokens": 512,
            "messages":   [["role": "user", "content": prompt]],
        ]

        var request = URLRequest(url: claudeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicAPIKey,    forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[Claude] Requesting insights for '\(foodName)' ...")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[Claude] HTTP error: \(statusCode)\n\(String(data: data, encoding: .utf8) ?? "<unreadable>")")
            throw NutritionAPIError.httpError(statusCode)
        }

        print("[Claude] Raw response:\n\(String(data: data, encoding: .utf8) ?? "<unreadable>")")

        struct ClaudeResponse: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }
        let claudeResp = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let raw = claudeResp.content.first?.text
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        print("[Claude] Extracted text:\n\(raw)")

        struct InsightsPayload: Decodable {
            let pairings: [String]
            let risks:    [String]
            let benefits: [String]
        }
        guard let jsonData = raw.data(using: .utf8),
              let payload  = try? JSONDecoder().decode(InsightsPayload.self, from: jsonData)
        else {
            print("[Claude] Failed to parse JSON from response")
            throw NutritionAPIError.invalidJSON
        }

        return FoodInsights(
            foodName: foodName,
            pairings: payload.pairings,
            risks:    payload.risks,
            benefits: payload.benefits
        )
    }
}
