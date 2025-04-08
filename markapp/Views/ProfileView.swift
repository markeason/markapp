import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 15) {
                        if viewModel.isEditing {
                            PhotosPicker(selection: $viewModel.photoPickerItem, matching: .images) {
                                if let image = viewModel.selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            if let image = viewModel.selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if viewModel.isEditing {
                            VStack(spacing: 10) {
                                TextField("Name", text: $viewModel.editingName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .multilineTextAlignment(.center)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                    
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.blue)
                                            .frame(width: 24)
                                        TextField("City, State, Country", text: $viewModel.editingLocation)
                                            .font(.body)
                                            .disableAutocorrection(true)
                                            .autocapitalization(.words)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                                            .background(Color(.systemBackground).cornerRadius(8))
                                    )
                                    
                                    if !viewModel.editingLocation.isEmpty {
                                        HStack {
                                            Image(systemName: "magnifyingglass")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Searching for locations...")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.top, 4)
                                        .opacity(viewModel.suggestedCities.isEmpty ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.2), value: viewModel.suggestedCities.isEmpty)
                                    }
                                    
                                    if !viewModel.suggestedCities.isEmpty {
                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(viewModel.suggestedCities, id: \.self) { city in
                                                Button(action: {
                                                    viewModel.editingLocation = city
                                                    viewModel.suggestedCities = []
                                                    hideKeyboard()
                                                }) {
                                                    HStack {
                                                        Image(systemName: "mappin.circle.fill")
                                                            .foregroundColor(.blue)
                                                            .frame(width: 24)
                                                        Text(city)
                                                            .foregroundColor(.primary)
                                                        Spacer()
                                                    }
                                                    .contentShape(Rectangle())
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 10)
                                                }
                                                if city != viewModel.suggestedCities.last {
                                                    Divider()
                                                        .padding(.leading, 40)
                                                }
                                            }
                                        }
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        .transition(.opacity)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.horizontal, 20)
                        } else {
                            Text(viewModel.user.name.isEmpty ? "Add Name" : viewModel.user.name)
                                .font(.title2)
                                .bold()
                            
                            if !viewModel.user.location.isEmpty {
                                Label(viewModel.user.location, systemImage: "location.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Sync indicator
                            if viewModel.isSyncing {
                                HStack(spacing: 5) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.7)
                                    Text("Syncing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 5)
                            }
                        }
                        
                        Text(viewModel.formattedJoinDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(viewModel.totalBooksRead)")
                                .font(.title2)
                                .bold()
                            Text("Books Read")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text(viewModel.totalReadingTime)
                                .font(.title2)
                                .bold()
                            Text("Total Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text(viewModel.totalPagesRead)
                                .font(.title2)
                                .bold()
                            Text("Pages Read")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Recent Books
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recent Books")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if viewModel.recentBooks.isEmpty {
                            Text("No books read yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(viewModel.recentBooks) { book in
                                HStack(spacing: 15) {
                                    if let coverURLString = book.coverURL {
                                        ImprovedCoverImageView(
                                            coverURLString: coverURLString,
                                            width: 50,
                                            height: 70
                                        )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(book.title)
                                            .font(.headline)
                                        Text(book.author)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                                
                                if book.id != viewModel.recentBooks.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Sign Out Button
                    Button(action: {
                        showingSignOutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .foregroundColor(.red)
                                .bold()
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isEditing ? "Save" : "Edit") {
                        if viewModel.isEditing {
                            viewModel.saveProfile()
                        } else {
                            viewModel.isEditing = true
                        }
                    }
                    .disabled(viewModel.isSyncing)
                }
            }
            .onAppear {
                // Fetch latest data from Supabase when the view appears
                Task {
                    await DataManager.shared.refreshData()
                    
                    // After refreshing from Supabase, update the local UI
                    DispatchQueue.main.async {
                        viewModel.refreshRecentBooks()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authManager.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Sync Error", isPresented: .constant(viewModel.syncError != nil)) {
                Button("OK") {
                    viewModel.syncError = nil
                }
            } message: {
                if let error = viewModel.syncError {
                    Text(error)
                } else {
                    Text("An unknown error occurred while syncing with the server.")
                }
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
