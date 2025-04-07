import SwiftUI

struct ImprovedCoverImageView: View {
    let coverURLString: String?
    let width: CGFloat
    let height: CGFloat
    @State private var debugInfo: String = ""
    
    var body: some View {
        Group {
            if let urlString = coverURLString, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let url = URL(string: cleanedURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderView
                                .onAppear {
                                    debugInfo = "Loading image from: \(cleanedURLString)"
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: height)
                                .clipped()
                                .cornerRadius(6)
                                .shadow(radius: 2)
                                .onAppear {
                                    debugInfo = "Successfully loaded image from: \(cleanedURLString)"
                                }
                        case .failure:
                            placeholderView
                                .onAppear {
                                    debugInfo = "Failed to load image from URL: \(cleanedURLString)"
                                }
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            // Book cover background with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width, height: height)
                .cornerRadius(6)
                .shadow(radius: 2)
            
            // Book content layout
            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: height * 0.15)
                
                // Book title area
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: width * 0.7, height: height * 0.1)
                
                Spacer()
                    .frame(height: height * 0.1)
                
                // Book icon
                Image(systemName: "book.closed")
                    .font(.system(size: width * 0.3))
                    .foregroundColor(Color.white.opacity(0.8))
                
                Spacer()
                    .frame(height: height * 0.1)
                
                // Author area
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: width * 0.5, height: height * 0.04)
                
                // Bottom spacing
                Spacer()
                    .frame(height: height * 0.15)
            }
        }
    }
} 