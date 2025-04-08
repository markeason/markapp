//
//  MainTabView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            
            RecordView()
                .tabItem {
                    Label("Record", systemImage: "timer")
                }
            
            CommunityFeedView()
                .environmentObject(authManager)
                .tabItem {
                    Label("Community", systemImage: "person.3")
                }
            
            ProfileView()
                .environmentObject(authManager)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}
