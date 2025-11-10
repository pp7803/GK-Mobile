//
//  AIService.swift
//  PPNote
//
//  Created by Phát Phạm on 22/10/25.
//

import Foundation
import Combine

class AIService: ObservableObject {
    static let shared = AIService()
    
    private let apiKey = "AIzaSyA7FefIqJ2UMxKvnm3Bq2xSd4MTnl446CI"
    private let models = [
        "gemini-2.0-flash",
        "gemini-2.5-pro"
    ]
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    @Published var isGenerating = false
    @Published var isGeneratingImage = false
    @Published var currentModel = "gemini-2.0-flash"
    
    private init() {}
    
    func generateNoteContent(from prompt: String) async throws -> String {
        await MainActor.run {
            isGenerating = true
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
            }
        }
        
        // Retry logic for 503 errors
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                //print("🔄 AI API Attempt \(attempt)/\(maxRetries)")
                return try await performAPICall(prompt: prompt)
            } catch AIError.serverError(503) {
                //print("⚠️ 503 Error on attempt \(attempt)/\(maxRetries), retrying in \(attempt * 2) seconds...")
                lastError = AIError.serverError(503)
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(attempt * 2 * 1_000_000_000)) // Wait 2, 4, 6 seconds
                }
            } catch {
                throw error // Other errors, don't retry
            }
        }
        
        throw lastError ?? AIError.serverError(503)
    }
    
    func generateImage(from prompt: String) async throws -> GeneratedImageResult {
        await MainActor.run {
            isGeneratingImage = true
        }
        
        defer {
            Task { @MainActor in
                isGeneratingImage = false
            }
        }
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await performImageAPICall(prompt: prompt)
            } catch AIError.serverError(503) {
                lastError = AIError.serverError(503)
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(attempt * 2 * 1_000_000_000))
                }
            } catch {
                throw error
            }
        }
        
        throw lastError ?? AIError.serverError(503)
    }
    
    private func performAPICall(prompt: String) async throws -> String {
        
        guard let url = URL(string: "\(baseURL)/\(currentModel):generateContent?key=\(apiKey)") else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            Bạn là một trợ lý AI chuyên tạo ghi chú chi tiết và có cấu trúc. 
                            Dựa trên yêu cầu sau, hãy tạo một ghi chú hoàn chỉnh với tiêu đề và nội dung:
                            
                            Yêu cầu: \(prompt)
                            
                            Hãy trả về theo định dạng:
                            TITLE: [Tiêu đề ngắn gọn]
                            CONTENT: [Nội dung chi tiết, có cấu trúc rõ ràng]
                            """
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        // Debug: Print request details
        //print("🚀 AI API Request URL: \(url)")
        //print("🚀 AI API Request Method: \(request.httpMethod ?? "Unknown")")
        //print("🚀 AI API Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let bodyString = String(data: jsonData, encoding: .utf8) {
            //print("🚀 AI API Request Body: \(bodyString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            //print("🔍 AI API Response Status: \(httpResponse.statusCode)")
            //print("🔍 AI API Response Headers: \(httpResponse.allHeaderFields)")
            
            if httpResponse.statusCode != 200 {
                // Debug: Print error response body
                if let errorString = String(data: data, encoding: .utf8) {
                    //print("❌ AI API Error Response Body: \(errorString)")
                }
                
                // Print specific error messages based on status code
                switch httpResponse.statusCode {
                case 400:
                    break;
                    //print("❌ 400 Bad Request - Check API request format or parameters")
                case 401:
                    break;
                    //print("❌ 401 Unauthorized - API key might be invalid or expired")
                case 403:
                    break;
                    //print("❌ 403 Forbidden - API key might not have permission")
                case 429:
                    break;
                    //print("❌ 429 Rate Limited - Too many requests")
                case 500:
                    break;
                    //print("❌ 500 Internal Server Error - Google's server error")
                case 503:
                    //print("❌ 503 Service Unavailable - Service temporarily down or overloaded")
                    //print("❌ This could be due to:")
                    //print("   - High traffic on Gemini API")
                    //print("   - Temporary service maintenance")
                    //print("   - Region-specific issues")
                    //print("   - Model temporarily unavailable")
                    break;
                default:
                    break;
                    //print("❌ HTTP Error \(httpResponse.statusCode)")
                }
                
                throw AIError.serverError(httpResponse.statusCode)
            }
        }
        
        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            //print("✅ AI API Raw Response: \(responseString)")
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            //print("❌ Failed to parse JSON response")
            throw AIError.invalidResponse
        }
        
        //print("📋 AI API Parsed JSON: \(jsonResponse)")
        
        // Parse response following Gemini API structure
        guard let candidates = jsonResponse["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            
            // Try alternative structure
            if let contents = jsonResponse["contents"] as? [[String: Any]],
               let firstContent = contents.first,
               let parts = firstContent["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                return text
            }
            
            throw AIError.noContent
        }
        
        return text
    }
    
    private func performImageAPICall(prompt: String) async throws -> GeneratedImageResult {
        let imageModel = "gemini-2.0-flash-preview-image-generation"
        
        guard let url = URL(string: "\(baseURL)/\(imageModel):generateContent?key=\(apiKey)") else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["TEXT", "IMAGE"]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw AIError.serverError(httpResponse.statusCode)
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonResponse["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIError.invalidResponse
        }
        
        var description: String?
        var imageData: Data?
        var mimeType: String = "image/png"
        
        for part in parts {
            if let text = part["text"] as? String {
                description = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let inlineData = part["inlineData"] as? [String: Any],
                      let base64 = inlineData["data"] as? String {
                imageData = Data(base64Encoded: base64)
                if let type = inlineData["mimeType"] as? String {
                    mimeType = type
                }
            }
        }
        
        guard let finalData = imageData else {
            throw AIError.noContent
        }
        
        return GeneratedImageResult(
            data: finalData,
            mimeType: mimeType,
            description: description
        )
    }
}

struct GeneratedImageResult {
    let data: Data
    let mimeType: String
    let description: String?
}

enum AIError: LocalizedError {
    case invalidURL
    case serverError(Int)
    case invalidResponse
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL không hợp lệ"
        case .serverError(let code):
            switch code {
            case 503:
                return "Dịch vụ AI tạm thời không khả dụng (503). Vui lòng thử lại sau vài giây."
            case 429:
                return "Quá nhiều yêu cầu (429). Vui lòng chờ một chút và thử lại."
            case 401:
                return "API key không hợp lệ (401)"
            case 400:
                return "Yêu cầu không hợp lệ (400)"
            default:
                return "Lỗi máy chủ: \(code)"
            }
        case .invalidResponse:
            return "Phản hồi không hợp lệ"
        case .noContent:
            return "Không có nội dung từ AI"
        }
    }
}
