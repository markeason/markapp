//
//  BookSelectionView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct BookSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let books: [Book]
    let onSelect: (Book) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(books) { book in
                    Button {
                        onSelect(book)
                        dismiss()
                    } label: {
                        HStack(spacing: 15) {
                            ImprovedCoverImageView(
                                coverURLString: book.coverURL,
                                width: 50,
                                height: 70
                            )

                            VStack(alignment: .leading, spacing: 5) {
                                Text(book.title)
                                    .font(.headline)
                                
                                Text(book.author)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if book.currentPage > 0 {
                                    Text("Continue from page \(book.currentPage)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        } // <- Closing brace for HStack
                        .padding(.vertical, 5)
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
