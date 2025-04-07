//
//  BookItemView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct BookItemView: View {
    let book: Book
    
    var body: some View {
        VStack {
            ImprovedCoverImageView(
                coverURLString: book.coverURL,
                width: 120,
                height: 180
            )
            
            Text(book.title)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Text(book.author)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if let total = book.totalPages, total > 0 {
                ProgressView(value: book.readingProgress)
                    .tint(.blue)
                
                Text("Page \(book.currentPage) of \(total)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 150)
        .padding(.bottom, 10)
    }
}
