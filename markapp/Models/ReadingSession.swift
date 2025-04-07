//
//  ReadingSession.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation

struct ReadingSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var bookID: UUID
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    var startPage: Int
    var endPage: Int?
    var pagesRead: Int? {
        guard let endPage = endPage else { return nil }
        return endPage - startPage
    }
    var aiSummary: String?
    var transcript: String?
    
    var readingTimeMinutes: Double {
        duration / 60.0
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
