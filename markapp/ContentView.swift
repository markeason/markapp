//
//  ContentView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to MarkApp!")
                    .font(.title)
                    .padding()
                
                Text("Use the tabs below to navigate through the app.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .padding()
            .navigationTitle("MarkApp")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
