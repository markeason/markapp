//
//  Book.swift 
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation

struct Book: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var isbn: String
    var title: String
    var author: String
    var coverURL: String?
    var currentPage: Int = 0
    var totalPages: Int?
    
    var readingProgress: Double {
        guard let total = totalPages, total > 0 else { return 0 }
        return Double(currentPage) / Double(total)
    }
}
