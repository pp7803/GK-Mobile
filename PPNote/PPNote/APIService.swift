import Foundation
import Combine

struct APIResponse<T: Codable>: Codable {
    let message: String?
    let data: T?
    let token: String?
    let user: APIUser?
}

struct APIUser: Codable {
    let id: Int
    let email: String
}

struct APINote: Codable {
    let id: String
    let title: String
    let content: String?
    let is_draft: Bool
    let temp_delete: Int
    let created_at: String
    let updated_at: String
    let synced_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, is_draft, temp_delete, created_at, updated_at, synced_at
    }
    
    init(id: String, title: String, content: String?, is_draft: Bool, temp_delete: Int, created_at: String, updated_at: String, synced_at: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.is_draft = is_draft
        self.temp_delete = temp_delete
        self.created_at = created_at
        self.updated_at = updated_at
        self.synced_at = synced_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        is_draft = try container.decode(Bool.self, forKey: .is_draft)
        temp_delete = try container.decodeIfPresent(Int.self, forKey: .temp_delete) ?? 0
        created_at = try container.decode(String.self, forKey: .created_at)
        updated_at = try container.decode(String.self, forKey: .updated_at)
        synced_at = try container.decodeIfPresent(String.self, forKey: .synced_at)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encode(is_draft, forKey: .is_draft)
        try container.encode(temp_delete, forKey: .temp_delete)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(synced_at, forKey: .synced_at)
    }
}

struct DeletedNotesSyncResponse: Codable {
    let deletedNotes: [APIDeletedNote]
    let lastSyncTime: String
}

struct DeletedNoteResponse: Codable {
    let id: String
    let title: String
    let content: String?
    let deleted_at: String
    let original_created_at: String
    let original_updated_at: String
}

struct APIDeletedNote: Codable, Identifiable {
    let id: String
    let title: String
    let content: String?
    let deleted_at: String
    let original_created_at: String?
    let original_updated_at: String?
}

struct SyncRequest: Codable {
    let notes: [APINote]
    let lastSyncTime: String?
}

struct SyncResponse: Codable {
    let serverNotes: [APINote]
    let conflicts: [SyncConflict]
    let synced: [String]
    let syncTime: String
}

struct SyncConflict: Codable {
    let noteId: String
    let reason: String
    let serverNote: APINote?
}

class APIService: ObservableObject {
    static let shared = APIService()
    
    let baseURL = "https://apinote.ppdeveloper.xyz/api"
    private let session = URLSession.shared
    
    // MARK: - Authentication
    
    func register(email: String, password: String) async throws -> (token: String, user: APIUser) {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🔄 Register request to: \(url)")
        print("📦 Request body: \(body)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw APIError.invalidResponse
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            print("📋 Response data: \(String(data: data, encoding: .utf8) ?? "No data")")
            
            if httpResponse.statusCode == 201 {
                let apiResponse = try JSONDecoder().decode(APIResponse<APIUser>.self, from: data)
                guard let token = apiResponse.token, let user = apiResponse.user else {
                    print("❌ Missing token or user in response")
                    throw APIError.invalidData
                }
                print("✅ Registration successful")
                return (token, user)
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                let errorMessage = errorResponse?.message ?? "Registration failed"
                print("❌ Registration failed: \(errorMessage)")
                throw APIError.serverError(errorMessage)
            }
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }
    
    func login(email: String, password: String) async throws -> (token: String, user: APIUser) {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🔄 Login request to: \(url)")
        print("📦 Request body: \(body)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw APIError.invalidResponse
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            print("📋 Response data: \(String(data: data, encoding: .utf8) ?? "No data")")
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(APIResponse<APIUser>.self, from: data)
                guard let token = apiResponse.token, let user = apiResponse.user else {
                    print("❌ Missing token or user in response")
                    throw APIError.invalidData
                }
                print("✅ Login successful")
                return (token, user)
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                let errorMessage = errorResponse?.message ?? "Login failed"
                print("❌ Login failed: \(errorMessage)")
                throw APIError.serverError(errorMessage)
            }
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }
    
    // MARK: - Notes
    
    func fetchNotes(token: String) async throws -> [APINote] {
        let url = URL(string: "\(baseURL)/notes")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([APINote].self, from: data)
        } else {
            throw APIError.serverError("Failed to fetch notes")
        }
    }
    
    func getNote(token: String, noteId: String) async throws -> APINote {
        let url = URL(string: "\(baseURL)/notes/\(noteId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(APINote.self, from: data)
        } else {
            throw APIError.serverError("Failed to get note")
        }
    }
    
    func createNote(token: String, id: String? = nil, title: String, content: String, isDraft: Bool) async throws -> APINote {
        let url = URL(string: "\(baseURL)/notes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "title": title,
            "content": content,
            "is_draft": isDraft
        ]
        if let id = id {
            body["id"] = id.lowercased()
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try JSONDecoder().decode(APINote.self, from: data)
        } else {
            throw APIError.serverError("Failed to create note")
        }
    }
    
    func updateNote(token: String, noteId: String, title: String?, content: String?, isDraft: Bool?) async throws -> APINote {
        let url = URL(string: "\(baseURL)/notes/\(noteId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [:]
        if let title = title { body["title"] = title }
        if let content = content { body["content"] = content }
        if let isDraft = isDraft { body["is_draft"] = isDraft }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(APINote.self, from: data)
        } else {
            throw APIError.serverError("Failed to update note")
        }
    }
    
    func deleteNote(token: String, noteId: String) async throws {
        print("APIService: Starting deleteNote request for noteId: \(noteId)")
        
        let url = URL(string: "\(baseURL)/notes/\(noteId)")!
        print("APIService: Delete URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("APIService: Sending DELETE request...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("APIService: Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("APIService: Delete response status: \(httpResponse.statusCode)")
            
            if let responseData = String(data: data, encoding: .utf8) {
                print("APIService: Delete response body: \(responseData)")
            }
            
            if httpResponse.statusCode != 200 {
                print("APIService: Delete failed with status: \(httpResponse.statusCode)")
                throw APIError.serverError("Failed to delete note")
            }
            
            print("APIService: Note deleted successfully")
            
        } catch {
            print("APIService: Delete request failed with error: \(error)")
            throw error
        }
    }
    
    // MARK: - Sync
    
    func syncNotes(token: String, notes: [Note], lastSyncTime: Date?) async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/notes/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let dateFormatter = ISO8601DateFormatter()
        
        let apiNotes = notes.map { note in
            APINote(
                id: note.id?.lowercased() ?? "", // Normalize UUID
                title: note.title ?? "",
                content: note.content,
                is_draft: note.isDraft,
                temp_delete: note.tempDelete ? 1 : 0,
                created_at: dateFormatter.string(from: note.createdAt ?? Date()),
                updated_at: dateFormatter.string(from: note.updatedAt ?? Date()),
                synced_at: note.syncedAt.map { dateFormatter.string(from: $0) }
            )
        }
        
        print("APIService: Syncing \(apiNotes.count) notes to server")
        
        let syncRequest = SyncRequest(
            notes: apiNotes,
            lastSyncTime: lastSyncTime.map { dateFormatter.string(from: $0) }
        )
        
        request.httpBody = try JSONEncoder().encode(syncRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let syncResponse = try JSONDecoder().decode(SyncResponse.self, from: data)
            print("APIService: Sync response received - \(syncResponse.serverNotes.count) server notes")
            
            // Debug log temp_delete values
            for note in syncResponse.serverNotes {
                print("APIService: Server note - id: \(note.id), title: \(note.title), temp_delete: \(note.temp_delete)")
            }
            
            return syncResponse
        } else {
            throw APIError.serverError("Sync failed")
        }
    }
    
    // MARK: - Deleted Notes
    
    func fetchDeletedNotes(token: String) async throws -> [APINote] {
        let url = URL(string: "\(baseURL)/notes/trash/all")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            // Parse as array of deleted notes from server
            let deletedNotes = try JSONDecoder().decode([DeletedNoteResponse].self, from: data)
            
            // Convert to APINote format
            return deletedNotes.map { deletedNote in
                APINote(
                    id: deletedNote.id,
                    title: deletedNote.title,
                    content: deletedNote.content,
                    is_draft: false, // Deleted notes are not drafts
                    temp_delete: 1, // Mark as deleted
                    created_at: deletedNote.original_created_at,
                    updated_at: deletedNote.original_updated_at
                )
            }
        } else {
            throw APIError.serverError("Failed to fetch deleted notes")
        }
    }
    
    func createDeletedNote(token: String, id: String, title: String, content: String, deletedAt: Date, originalCreatedAt: Date?, originalUpdatedAt: Date?) async throws {
        let url = URL(string: "\(baseURL)/notes/trash")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        
        let requestBody: [String: Any] = [
            "id": id,
            "title": title,
            "content": content,
            "deletedAt": dateFormatter.string(from: deletedAt),
            "originalCreatedAt": originalCreatedAt != nil ? dateFormatter.string(from: originalCreatedAt!) : nil,
            "originalUpdatedAt": originalUpdatedAt != nil ? dateFormatter.string(from: originalUpdatedAt!) : nil
        ].compactMapValues { $0 }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 {
            throw APIError.serverError("Failed to create deleted note")
        }
    }
    
    func syncDeletedNotes(token: String, lastSyncTime: Date?) async throws -> [APIDeletedNote] {
        var url = URL(string: "\(baseURL)/notes/trash/sync")!
        
        if let lastSyncTime = lastSyncTime {
            let dateFormatter = ISO8601DateFormatter()
            let lastSyncString = dateFormatter.string(from: lastSyncTime)
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "lastSyncTime", value: lastSyncString)]
            url = components.url!
        }
        
        //print("APIService: Calling URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        //print("APIService: Response status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                //print("APIService: Raw response: \(responseString)")
            }
            
            let syncResponse = try JSONDecoder().decode(DeletedNotesSyncResponse.self, from: data)
            //print("APIService: Decoded \(syncResponse.deletedNotes.count) deleted notes")
            return syncResponse.deletedNotes
        } else {
            if let responseString = String(data: data, encoding: .utf8) {
                //print("APIService: Error response: \(responseString)")
            }
            throw APIError.serverError("Failed to sync deleted notes")
        }
    }
    
    func restoreNote(token: String, noteId: String) async throws {
        let url = URL(string: "\(baseURL)/notes/trash/\(noteId)/restore")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.serverError("Failed to restore note")
        }
    }
    
    func permanentlyDeleteNote(token: String, noteId: String) async throws {
        let url = URL(string: "\(baseURL)/notes/trash/\(noteId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.serverError("Failed to permanently delete note")
        }
    }
    
    // MARK: - Password Reset API Methods
    
    func requestPasswordReset(email: String) async throws -> (success: Bool, message: String) {
        let url = URL(string: "\(baseURL)/auth/forgot-password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🔄 Password reset request to: \(url)")
        print("📦 Request body: \(body)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw APIError.invalidResponse
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            print("📋 Response data: \(String(data: data, encoding: .utf8) ?? "No data")")
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = json?["message"] as? String ?? "Unknown error"
            
            switch httpResponse.statusCode {
            case 200:
                print("✅ Password reset request successful")
                return (success: true, message: message)
            case 429:
                print("⚠️ Rate limited")
                return (success: false, message: message)
            case 400:
                print("❌ Bad request")
                return (success: false, message: message)
            default:
                print("❌ Request failed with status \(httpResponse.statusCode)")
                throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
            }
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }
    
    func verifyOTP(email: String, otp: String) async throws -> (success: Bool, message: String, resetToken: String?) {
        let url = URL(string: "\(baseURL)/auth/verify-otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "otp": otp]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = json?["message"] as? String ?? "Unknown error"
        let resetToken = json?["resetToken"] as? String
        
        switch httpResponse.statusCode {
        case 200:
            return (success: true, message: message, resetToken: resetToken)
        case 400:
            return (success: false, message: message, resetToken: nil)
        default:
            throw APIError.serverError("Verification failed with status \(httpResponse.statusCode)")
        }
    }
    
    func resetPassword(token: String, newPassword: String) async throws -> (success: Bool, message: String) {
        let url = URL(string: "\(baseURL)/auth/reset-password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["resetToken": token, "newPassword": newPassword]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = json?["message"] as? String ?? "Unknown error"
        
        switch httpResponse.statusCode {
        case 200:
            return (success: true, message: message)
        case 400:
            return (success: false, message: message)
        default:
            throw APIError.serverError("Password reset failed with status \(httpResponse.statusCode)")
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case invalidData
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Invalid data received"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - APINote Extensions
extension APINote {
    var updatedAt: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: updated_at)
    }
    
    var createdAt: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: created_at)
    }
    
    var syncedAtDate: Date? {
        guard let syncedAtString = synced_at else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: syncedAtString)
    }
    
    var isDraft: Bool {
        return is_draft
    }
}
