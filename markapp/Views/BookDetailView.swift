//
//  BookDetailView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct BookDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: BookDetailViewModel
    @State private var showDeleteAlert = false
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(book: book))
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Book cover and info
                HStack(alignment: .top, spacing: 20) {
                    ImprovedCoverImageView(
                        coverURLString: viewModel.book.coverURL,
                        width: 120,
                        height: 180
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(viewModel.book.author)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if let total = viewModel.book.totalPages {
                            Text("Pages: \(total)")
                                .font(.subheadline)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                ProgressView(value: viewModel.book.readingProgress)
                                    .tint(.blue)
                                
                                Text("Currently on page \(viewModel.book.currentPage)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Reading stats
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reading Stats")
                        .font(.headline)
                    
                    HStack {
                        StatItemView(
                            value: viewModel.formattedTotalTime(),
                            label: "Total Time",
                            iconName: "clock"
                        )
                        
                        Divider()
                        
                        StatItemView(
                            value: "\(viewModel.totalPagesRead)",
                            label: "Pages Read",
                            iconName: "doc.text"
                        )
                        
                        Divider()
                        
                        StatItemView(
                            value: "\(viewModel.sessions.count)",
                            label: "Sessions",
                            iconName: "calendar"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Reading sessions
                SessionListView(sessions: viewModel.sessions)
            }
            .padding()
        }
        .refreshable {
            // Pull to refresh functionality
            await viewModel.refreshData()
        }
        .overlay(
            viewModel.isRefreshing ? 
            ProgressView("Refreshing...")
                .padding()
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(10)
                .shadow(radius: 3)
            : nil
        )
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Book", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteBook()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(viewModel.book.title)'? This will remove all reading history for this book.")
        }
        .onAppear {
            // Load data from local storage first
            viewModel.loadSessions()
            
            // Then refresh from Supabase
            Task {
                await viewModel.refreshData()
            }
        }
    }
}

struct SessionListView: View {
    let sessions: [ReadingSession]
    @State private var displayCount = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reading History")
                .font(.headline)
            
            if sessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No reading sessions yet")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(sessions.prefix(displayCount).enumerated()), id: \.element.id) { _, session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            SessionItemView(session: session)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if displayCount < sessions.count {
                        Button(action: {
                            displayCount = min(displayCount + 5, sessions.count)
                        }) {
                            Text("Load more sessions")
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
