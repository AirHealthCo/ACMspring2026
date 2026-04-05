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
                  candidates: [(label: String, confidence: Float)]) async throws -> (String, [String]) {

        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
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

        Look at the image and identify what food is actually shown.
        - If the top guess looks correct, respond with that label (underscores, no spaces).
        - If the top guess seems wrong, ignore it and respond with the correct food name \
        (e.g.: apple, grilled_salmon, birthday_cake). You are not limited to the classifier's list.
        - Respond with the food label only. No other text.
        """

        print("[Claude] Prompt sent:\n\(prompt)")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 64,
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
        let finalLabel = decoded.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? candidates[0].label
        print("[Claude] Raw response: \"\(finalLabel)\"")

        var debugLines: [String] = []
        debugLines.append("=== Claude ===")
        debugLines.append("Prompt candidates:")
        for line in candidateLines.split(separator: "\n") { debugLines.append("  \(line)") }
        debugLines.append("→ Claude answer: \"\(finalLabel)\"")
        let topMLLabel = candidates[0].label
        if finalLabel != topMLLabel {
            debugLines.append("⚠ Overrode ML guess (\(topMLLabel))")
        }

        return (finalLabel, debugLines)
    }
}

// MARK: - Response model

private struct ClaudeResponse: Codable {
    struct Content: Codable { let text: String }
    let content: [Content]
}

// MARK: - Errors

enum ClaudeError: Error {
    case imageEncodingFailed
    case badResponse
}
