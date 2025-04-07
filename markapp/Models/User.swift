import Foundation

struct User: Codable {
    var name: String
    var location: String
    var joinDate: Date
    var profilePhotoData: Data?
    
    static var empty: User {
        User(name: "", location: "", joinDate: Date(), profilePhotoData: nil)
    }
} 