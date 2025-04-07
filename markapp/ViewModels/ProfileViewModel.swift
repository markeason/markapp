import Foundation
import Combine
import CoreLocation
import UIKit
import PhotosUI
import SwiftUI

// Helper extension for unique elements
extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var recentBooks: [Book] = []
    @Published var isEditing = false
    @Published var editingName = ""
    @Published var editingLocation = ""
    @Published var suggestedCities: [String] = []
    @Published var isShowingImagePicker = false
    @Published var selectedImage: UIImage?
    @Published var photoPickerItem: PhotosPickerItem?
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.user = DataManager.shared.loadUser()
        self.recentBooks = DataManager.shared.getRecentlyReadBooks()
        self.editingName = user.name
        self.editingLocation = user.location
        
        if let photoData = user.profilePhotoData {
            self.selectedImage = UIImage(data: photoData)
        }
        
        setupLocationSearch()
        setupPhotoPickerObserver()
        setupSupabaseSync()
    }
    
    private func setupSupabaseSync() {
        // Listen for user changes from Supabase
        SupabaseManager.shared.userPublisher
            .sink { [weak self] _ in
                Task {
                    await self?.refreshUserData()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func refreshUserData() async {
        // Get the latest user data
        let updatedUser = DataManager.shared.loadUser()
        self.user = updatedUser
        self.editingName = user.name
        self.editingLocation = user.location
        
        if let photoData = user.profilePhotoData {
            self.selectedImage = UIImage(data: photoData)
        } else {
            self.selectedImage = nil
        }
    }
    
    private func setupPhotoPickerObserver() {
        $photoPickerItem
            .compactMap { $0 }
            .sink { [weak self] item in
                guard let self = self else { return }
                
                // Create a local copy to avoid Swift 6 concurrency warning
                let viewModel = self
                
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.selectedImage = image
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupLocationSearch() {
        $editingLocation
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.searchCities(query)
            }
            .store(in: &cancellables)
    }
    
    // Alternative approach if the above still doesn't work
    private func setupLocationSearchAlternative() {
        let cancellable = $editingLocation
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.searchCities(query)
            }
        cancellables.insert(cancellable)
    }
    
    private func searchCities(_ query: String) {
        guard !query.isEmpty else {
            suggestedCities = []
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { [weak self] placemarks, error in
            guard let placemarks = placemarks, error == nil else {
                self?.suggestedCities = []
                return
            }
            
            // Get unique cities, prioritizing exact matches
            let cities = placemarks
                .compactMap { $0.locality }
                .filter { $0.lowercased().contains(query.lowercased()) }
                .uniqued()
                .prefix(5)
                .map { String($0) }
            
            DispatchQueue.main.async {
                self?.suggestedCities = cities
            }
        }
    }
    
    func saveProfile() {
        // First update local model
        user.name = editingName
        user.location = editingLocation
        if let image = selectedImage {
            user.profilePhotoData = image.jpegData(compressionQuality: 0.8)
        }
        
        // Save to local storage and trigger Supabase sync
        DataManager.shared.saveUser(user)
        
        // Show syncing indicator for better UX
        isSyncing = true
        
        // Check sync status after a delay
        Task {
            // Give time for sync to complete
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                isSyncing = false
            }
        }
        
        isEditing = false
    }
    
    func refreshRecentBooks() {
        recentBooks = DataManager.shared.getRecentlyReadBooks()
        
        // Also refresh user data
        Task {
            await DataManager.shared.refreshData()
        }
    }
    
    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Joined \(formatter.string(from: user.joinDate))"
    }
    
    var totalBooksRead: Int {
        let sessions = DataManager.shared.loadSessions()
        let uniqueBookIDs = Set(sessions.compactMap { $0.endTime != nil ? $0.bookID : nil })
        return uniqueBookIDs.count
    }
    
    var totalReadingTime: String {
        let sessions = DataManager.shared.loadSessions()
        let totalMinutes = sessions.reduce(0) { $0 + $1.readingTimeMinutes }
        let hours = Int(totalMinutes / 60)
        let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var totalPagesRead: String {
        let sessions = DataManager.shared.loadSessions()
        let totalPages = sessions.reduce(into: 0) { result, session in
            result += session.pagesRead ?? 0  // Using nil coalescing in case pagesRead is optional
        }
        
        if totalPages >= 1000000 {
            return String(format: "%.1fM", Double(totalPages) / 1000000.0)
        } else if totalPages >= 1000 {
            return String(format: "%.1fK", Double(totalPages) / 1000.0)
        } else {
            return "\(totalPages)"
        }
    }
}
