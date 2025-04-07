//
//  LibraryView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showingAddSheet = false
    @State private var showingProfile = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 20)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.books.isEmpty {
                    // Empty State View
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 70))
                            .foregroundColor(.gray)
                            .padding(.top, 100)
                        
                        Text("Your library is empty")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Button("Add Your First Book") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Grid of Books
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.books) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                BookItemView(book: book)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deleteBook(withID: book.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        
                        // Add Book Button in Grid
                        Button {
                            showingAddSheet = true
                        } label: {
                            VStack {
                                Image(systemName: "plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                    .frame(width: 150, height: 200)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                Text("Add Book")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                }
            }
            .refreshable {
                // Pull to refresh functionality
                await viewModel.refreshBooks()
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
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.system(size: 22))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                BookAddView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
            .onAppear {
                // Load books from local storage first
                viewModel.loadBooks()
                
                // Then refresh from Supabase
                Task {
                    await viewModel.refreshBooks()
                }
            }
        }
    }
}
