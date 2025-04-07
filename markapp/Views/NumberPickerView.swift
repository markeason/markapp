//
//  File.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct NumberPickerView: View {
    @Binding var selectedNumber: Int
    let title: String
    let range: ClosedRange<Int>
    let step: Int
    @Environment(\.dismiss) private var dismiss
    
    init(selectedNumber: Binding<Int>, title: String, range: ClosedRange<Int> = 1...1000, step: Int = 1) {
        self._selectedNumber = selectedNumber
        self.title = title
        self.range = range
        self.step = step
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Custom picker with blur effect
                ZStack {
                    // Gradient mask for top and bottom fade - reduced top opacity
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemBackground).opacity(0.6),
                            Color(.systemBackground).opacity(0.0),
                            Color(.systemBackground).opacity(0.0),
                            Color(.systemBackground).opacity(0.8)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                    .allowsHitTesting(false)
                    
                   
                    // The actual picker
                    Picker("", selection: $selectedNumber) {
                        ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: step)), id: \.self) { number in
                            Text("\(number)")
                                .tag(number)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                }
                .padding(.vertical)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
