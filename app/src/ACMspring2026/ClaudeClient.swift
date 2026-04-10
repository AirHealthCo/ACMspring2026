// ClaudeClient.swift
import Foundation
import UIKit

actor ClaudeClient {
    static let shared = ClaudeClient()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // Load API key from Secrets.plist — never hardcode
    private let apiKey: String = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key  = dict["ANTHROPIC_API_KEY"] as? String
        else { fatalError("Missing Secrets.plist or ANTHROPIC_API_KEY key") }
        return key
    }()

    func identify(image: UIImage,
                  candidates: [(label: String, confidence: Float)]) async throws -> (label: String, usdaQuery: String, dataType: String, debugLines: [String]) {

        let resized = image.resizedToMaxDimension(1024)
        guard let imageData = resized.jpegData(compressionQuality: 0.8) else {
            throw ClaudeError.imageEncodingFailed
        }
        let base64Image = imageData.base64EncodedString()

        let candidateLines = candidates.enumerated().map { i, c in
            "\(i + 1). \(c.label.replacingOccurrences(of: "_", with: " ")) " +
            "(classifier confidence: \(Int(c.confidence * 100))%)"
        }.joined(separator: "\n")

        let prompt = """
        A food classifier's top guesses for this image are:
        \(candidateLines)

        Look at the image and identify what food is shown. Respond with ONLY valid JSON, no markdown:
        {
          "label": "<short food name, underscores for spaces, e.g. grilled_salmon>",
          "usdaQuery": "<a concise description of the food as it would appear in a USDA database, e.g. 'salmon grilled' or 'apple raw'>",
          "dataType": "<'Foundation' for whole/raw/minimally-processed foods, 'SR Legacy' for prepared or packaged foods>"
        }
        """

        print("[Claude] Prompt sent:\n\(prompt)")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 128,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64Image
                        ]
                    ],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let rawBody = String(data: data, encoding: .utf8) ?? "<unreadable>"
            print("[Claude] Error response: \(rawBody)")
            throw ClaudeError.badResponse
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let raw = decoded.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("[Claude] Raw response: \(raw)")

        struct ClaudeFood: Decodable {
            let label: String
            let usdaQuery: String
            let dataType: String
        }
        let parsed: ClaudeFood
        if let jsonData = raw.data(using: .utf8),
           let p = try? JSONDecoder().decode(ClaudeFood.self, from: jsonData) {
            parsed = p
        } else {
            // Fallback: treat raw text as label
            parsed = ClaudeFood(label: raw, usdaQuery: raw, dataType: "Foundation")
        }

        let topMLLabel = candidates[0].label
        var debugLines: [String] = []
        debugLines.append("=== Claude ===")
        debugLines.append("Prompt candidates:")
        for line in candidateLines.split(separator: "\n") { debugLines.append("  \(line)") }
        debugLines.append("→ label: \"\(parsed.label)\"")
        debugLines.append("→ usdaQuery: \"\(parsed.usdaQuery)\"")
        debugLines.append("→ dataType: \"\(parsed.dataType)\"")
        if parsed.label != topMLLabel {
            debugLines.append("⚠ Overrode ML guess (\(topMLLabel))")
        }

        return (parsed.label, parsed.usdaQuery, parsed.dataType, debugLines)
    }
}

// MARK: - Response model

private struct ClaudeResponse: Codable {
    struct Content: Codable { let text: String }
    let content: [Content]
}

// MARK: - UIImage resize helper

private extension UIImage {
    func resizedToMaxDimension(_ maxDim: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDim else { return self }
        let scale = maxDim / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - Errors

enum ClaudeError: Error {
    case imageEncodingFailed
    case badResponse
}
