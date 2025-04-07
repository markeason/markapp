//
//  StatItemView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct StatItemView: View {
    let value: String
    let label: String
    let iconName: String
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
