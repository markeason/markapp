//
//  BookService.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation

class BookService {
    static let shared = BookService()
    
    private init() {}
    
    func fetchBookDetails(isbn: String) async throws -> Book {
        // Using Google Books API for the MVP
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(GoogleBooksResponse.self, from: data)
        
        guard let item = response.items?.first, let volumeInfo = item.volumeInfo else {
            throw NSError(domain: "BookService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Book not found"])
        }
        
        // Clean up the thumbnail URL
        var thumbnailURL = volumeInfo.imageLinks?.thumbnail ?? ""
        print("Debug - Original thumbnail URL: \(thumbnailURL)")
        
        // Remove line breaks and spaces
        thumbnailURL = thumbnailURL.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        print("Debug - Cleaned thumbnail URL: \(thumbnailURL)")
        
        // Transform the URL for better quality
        if !thumbnailURL.isEmpty {
            // Extract the book ID from the URL
            if let bookID = thumbnailURL.components(separatedBy: "id=").last?.components(separatedBy: "&").first {
                print("Debug - Extracted book ID: \(bookID)")
                
                // Try different URL formats
                let urlFormats = [
                    "https://books.google.com/books/publisher/content/images/frontcover/\(bookID)?fife=w400-h600&source=gbs_api",
                    "https://books.google.com/books/content?id=\(bookID)&printsec=frontcover&img=1&zoom=2&source=gbs_api",
                    "https://books.google.com/books/content?id=\(bookID)&printsec=frontcover&img=1&zoom=1&source=gbs_api"
                ]
                
                // Test each URL format
                for (index, url) in urlFormats.enumerated() {
                    print("Debug - Testing URL format \(index + 1): \(url)")
                    if let url = URL(string: url) {
                        do {
                            let (_, response) = try await URLSession.shared.data(from: url)
                            if let httpResponse = response as? HTTPURLResponse {
                                print("Debug - URL \(index + 1) status code: \(httpResponse.statusCode)")
                                if httpResponse.statusCode == 200 {
                                    thumbnailURL = url.absoluteString
                                    print("Debug - Using successful URL format \(index + 1)")
                                    break
                                }
                            }
                        } catch {
                            print("Debug - URL \(index + 1) error: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                print("Debug - Could not extract book ID from URL")
                thumbnailURL = ""
            }
        } else {
            print("Debug - No thumbnail URL provided by API")
        }
        
        print("Debug - Final thumbnail URL: \(thumbnailURL)")
        
        return Book(
            isbn: isbn,
            title: volumeInfo.title,
            author: volumeInfo.authors?.joined(separator: ", ") ?? "Unknown",
            coverURL: thumbnailURL.isEmpty ? "" : thumbnailURL,
            totalPages: volumeInfo.pageCount
        )
    }
}

// Google Books API Response structures
struct GoogleBooksResponse: Codable {
    let items: [GoogleBookItem]?
}

struct GoogleBookItem: Codable {
    let volumeInfo: GoogleVolumeInfo?
}

struct GoogleVolumeInfo: Codable {
    let title: String
    let authors: [String]?
    let description: String?
    let pageCount: Int?
    let imageLinks: GoogleImageLinks?
}

struct GoogleImageLinks: Codable {
    let thumbnail: String?
}
