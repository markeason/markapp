import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var user: User
    @Published var totalPagesToday: Int = 0
    @Published var recentBook: Book?
    
    init() {
        self.user = DataManager.shared.loadUser()
        self.calculateTodaysPagesRead()
        self.fetchMostRecentBook()
    }
    
    func calculateTodaysPagesRead() {
        let sessions = DataManager.shared.loadSessions()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        totalPagesToday = sessions.reduce(0) { total, session in
            // Only count sessions that ended today
            guard let endTime = session.endTime,
                  calendar.isDate(endTime, inSameDayAs: today),
                  let pagesRead = session.pagesRead else {
                return total
            }
            return total + pagesRead
        }
    }
    
    func fetchMostRecentBook() {
        let sessions = DataManager.shared.loadSessions()
            .filter { $0.endTime != nil }
            .sorted { ($0.endTime ?? Date()) > ($1.endTime ?? Date()) }
        
        if let mostRecentSession = sessions.first {
            let allBooks = DataManager.shared.loadBooks()
            recentBook = allBooks.first { $0.id == mostRecentSession.bookID }
        }
    }
    
    func refreshData() {
        self.user = DataManager.shared.loadUser()
        self.calculateTodaysPagesRead()
        self.fetchMostRecentBook()
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Welcome section
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back,")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.user.name.isEmpty ? "Reader" : viewModel.user.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Today's summary
                    VStack(spacing: 16) {
                        Text("Today's Reading")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Text("\(viewModel.totalPagesToday)")
                                    .font(.system(size: 42, weight: .medium))
                                    .foregroundColor(.blue)
                                
                                Text("Pages Read Today")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Most recent book
                    VStack(spacing: 16) {
                        Text("Most Recent Book")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let book = viewModel.recentBook {
                            NavigationLink(destination: BookDetailView(book: book)) {
                                HStack(spacing: 15) {
                                    ImprovedCoverImageView(
                                        coverURLString: book.coverURL,
                                        width: 60,
                                        height: 90
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(book.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        
                                        Text(book.author)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                    
                                    Text("No books read yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.refreshData()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
} 