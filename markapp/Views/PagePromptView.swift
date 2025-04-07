//
//  PagePromptView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct PagePromptView: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let message: String
    let maxPages: Int
    
    @State private var selectedPage: Int
    let onComplete: (Int) -> Void
    
    init(title: String, message: String, initialPage: Int = 1, maxPages: Int = 1000, onComplete: @escaping (Int) -> Void) {
        self.title = title
        self.message = message
        self.maxPages = maxPages
        self.onComplete = onComplete
        _selectedPage = State(initialValue: initialPage)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                // Page number picker
                NumberPickerView(
                    selectedNumber: $selectedPage,
                    title: title,
                    range: 1...maxPages
                )
                .frame(height: 150)
                
                Button {
                    onComplete(selectedPage)
                    dismiss()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
