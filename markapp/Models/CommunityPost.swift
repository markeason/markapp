import Foundation

struct CommunityPost: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var userID: String
    var userName: String
    var bookID: UUID
    var sessionID: UUID
    var title: String
    var body: String
    var createdAt: Date
    
    // Related data (populated when needed)
    var book: Book?
    var session: ReadingSession?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
    
    // Ensure body text is limited to 300 characters
    var limitedBody: String {
        if body.count <= 300 {
            return body
        }
        let index = body.index(body.startIndex, offsetBy: 297)
        return String(body[..<index]) + "..."
    }
} 