//
//  SessionItemView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//
import SwiftUI

struct SessionItemView: View {
    let session: ReadingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let pagesRead = session.pagesRead {
                HStack {
                    Text("Pages: \(session.startPage) - \(session.endPage ?? 0)")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if session.readingTimeMinutes > 0 {
                        Text("\(Int(Double(pagesRead) / session.readingTimeMinutes)) pages/min")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
