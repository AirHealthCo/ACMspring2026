//
//  USDAAPI.swift
//  ACMspring2026
//
//  Created by Ruthvik Penubarthi on 3/9/26.
//
import Foundation

class USDAFoodData: FoodData {
    
    var APIKEY = ""
    // Make a private api key in a file called Secrets.plist
    init() {
            if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
               let key = dict["USDA_API_KEY"] as? String {
            self.APIKEY = key
            print(APIKEY)
            } else {
                print("Secrets.plist not found or API key missing")
            }
        }

    struct FoodResponse: Codable {
        let foods: [Food]
    }

    struct Food: Codable {
        let description: String
        let foodNutrients: [Nutrient]
    }

    struct Nutrient: Codable {
        let nutrientName: String
        let value: Double
    }


    func getData(query: String) async throws -> EssentialNutrients {
        let endpoint = "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(APIKEY)&query=\(query)"
        let url = URL(string: endpoint)!
        let urlRequest = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
       
        let decoded = try JSONDecoder().decode(FoodResponse.self, from: data)

        if !decoded.foods.isEmpty {
            for nutrient in decoded.foods[0].foodNutrients {
                switch nutrient.nutrientName {
                    case "Carbohydrate, by difference":
                        EssentialNutrients.shared.carbs = String(format: "%.1f", nutrient.value)

                    case "Sugars, total including NLEA":
                        EssentialNutrients.shared.sugars = String(format: "%.1f", nutrient.value)

                    case "Energy":
                        EssentialNutrients.shared.calories = String(format: "%.1f", nutrient.value)

                    case "Protein":
                        EssentialNutrients.shared.protein = String(format: "%.1f", nutrient.value)

                    case "Fatty acids, total saturated":
                        EssentialNutrients.shared.satFat = String(format: "%.1f", nutrient.value)
                    
                    case "Fatty acids, total trans":
                            EssentialNutrients.shared.transFat = String(format: "%.1f", nutrient.value)
                    default:
                        break
                    }
            }
        }
        
        return EssentialNutrients.shared
    }
}
