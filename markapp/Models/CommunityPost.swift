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
    
    // Ensure body text is limited to 200 characters
    var limitedBody: String {
        body.count <= 200 ? body : String(body.prefix(197)) + "..."
    }
    
    // Display a default name if user name is empty
    var displayName: String {
        if userName.isEmpty {
            return "Reader \(userID.prefix(4))"
        }
        return userName
    }
} 