//
//  AIService.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation

class AIService {
    static let shared = AIService()
    private let apiKey = AppConfig.openAIAPIKey // Using configuration value instead of hardcoded key
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    private init() {}
    
    func generateReadingSummary(book: Book, startPage: Int, endPage: Int) async throws -> String {
        // Create the prompt
        let prompt = """
        Generate a summary of pages \(startPage) to \(endPage) of the book "\(book.title)" by \(book.author).
        Focus on likely plot developments, character growth, and key themes that might appear in these pages.
        Format as 2-3 concise paragraphs.
        """
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo", // Or your preferred model
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that creates concise book summaries."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 300
        ]
        
        // Prepare the request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make the request
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AIResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "Summary could not be generated."
    }
}

// Response structures
struct AIResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String
}
