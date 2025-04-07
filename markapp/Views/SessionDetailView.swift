//
//  SessionDetailView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI

struct SessionDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: SessionDetailViewModel
    @State private var showDeleteAlert = false

    init(session: ReadingSession) {
        _viewModel = StateObject(wrappedValue: SessionDetailViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Book info
                if let book = viewModel.book {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Book")
                            .font(.headline)
                        
                        HStack(alignment: .top, spacing: 20) {
                            ImprovedCoverImageView(
                                coverURLString: book.coverURL,
                                width: 80,
                                height: 120
                            )
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(book.title)
                                    .font(.headline)
                                
                                Text(book.author)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Session stats
                VStack(alignment: .leading, spacing: 10) {
                    Text("Session Stats")
                        .font(.headline)
                    
                    HStack {
                        StatItemView(
                            value: viewModel.session.formattedDuration,
                            label: "Duration",
                            iconName: "clock"
                        )
                        
                        Divider()
                        
                        StatItemView(
                            value: "\(viewModel.session.pagesRead ?? 0)",
                            label: "Pages Read",
                            iconName: "doc.text"
                        )
                        
                        Divider()
                        
                        StatItemView(
                            value: "\(viewModel.readingSpeed) pgs",
                            label: "per minute",
                            iconName: "speedometer"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // AI Summary
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("AI Summary")
                            .font(.headline)
                        
                        Spacer()
                        
                        if viewModel.isLoadingSummary {
                            ProgressView()
                        } else if viewModel.session.aiSummary == nil {
                            Button {
                                Task {
                                    await viewModel.generateSummary()
                                }
                            } label: {
                                Text("Generate")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    if let error = viewModel.summaryError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    } else if let summary = viewModel.session.aiSummary {
                        Text(summary)
                            .font(.body)
                    } else if !viewModel.isLoadingSummary {
                        Text(viewModel.placeholderSummary)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Transcript
                if let transcript = viewModel.session.transcript, !transcript.isEmpty {
                    DisclosureGroup("Voice Transcript") {
                        Text(transcript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Session", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteSession()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this reading session? This action cannot be undone.")
        }
    }
}
