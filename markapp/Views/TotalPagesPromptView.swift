import SwiftUI

struct TotalPagesPromptView: View {
    let book: Book
    let onComplete: (Book) -> Void
    let onCancel: () -> Void
    
    @State private var totalPages: Int = 100
    @State private var showingPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Book details
                VStack(spacing: 16) {
                    if let coverURL = book.coverURL, !coverURL.isEmpty {
                        ImprovedCoverImageView(
                            coverURLString: coverURL,
                            width: 120,
                            height: 180
                        )
                    }
                    
                    Text(book.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Divider()
                
                // Page count selection
                VStack(spacing: 16) {
                    Text("How many pages does this book have?")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("We couldn't find this information automatically.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showingPicker = true
                    } label: {
                        HStack {
                            Text("\(totalPages) pages")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .sheet(isPresented: $showingPicker) {
                        NumberPickerView(
                            selectedNumber: $totalPages,
                            title: "Total Pages",
                            range: 1...2000,
                            step: 1
                        )
                        .presentationDetents([.medium])
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        var updatedBook = book
                        updatedBook.totalPages = totalPages
                        onComplete(updatedBook)
                    } label: {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button {
                        onCancel()
                    } label: {
                        Text("Skip")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
} 