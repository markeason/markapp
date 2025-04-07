//
//  BookAddView.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import SwiftUI
import AVFoundation

struct BookAddView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isbn = ""
    @State private var showingISBNEntry = false
    @FocusState private var isISBNFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                if showingISBNEntry {
                    // ISBN Entry View
                    ScrollView {
                        VStack(spacing: 30) {
                            Spacer().frame(height: 20)
                            
                            VStack(spacing: 20) {
                                Text("Enter ISBN")
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                
                                Text("Enter the 10 or 13-digit ISBN number")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                TextField("ISBN number", text: $isbn)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($isISBNFocused)
                                    .padding(.horizontal, 5)
                                
                                if let error = viewModel.errorMessage {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                
                                Button {
                                    Task {
                                        await viewModel.addBookByISBN(isbn)
                                        
                                        // Use the same logic as the barcode scanner
                                        if viewModel.showingTotalPagesPrompt {
                                            // Don't dismiss, we're showing the total pages prompt
                                        } else if viewModel.errorMessage == nil {
                                            // Success and no prompt needed, dismiss the view
                                            dismiss()
                                        }
                                        // If there's an error, it will show in the UI
                                    }
                                } label: {
                                    Text(viewModel.isLoading ? "Searching..." : "Search")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(isbn.isEmpty || viewModel.isLoading)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(15)
                            
                            Button {
                                showingISBNEntry = false
                            } label: {
                                HStack {
                                    Image(systemName: "barcode.viewfinder")
                                    Text("Scan ISBN")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            Spacer().frame(height: 40)
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                } else {
                    // Camera View
                    ZStack {
                        CameraScannerView(isbn: $isbn)
                            .onChange(of: isbn) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    Task {
                                        await viewModel.addBookByISBN(newValue)
                                        
                                        // Handle the result based on view model state
                                        if viewModel.showingTotalPagesPrompt {
                                            // Don't dismiss, we're showing the total pages prompt
                                            // This will keep the camera screen visible underneath
                                            // while the total pages prompt appears as a sheet
                                        } else if viewModel.errorMessage != nil {
                                            // Show the ISBN entry view if there was an error
                                            showingISBNEntry = true
                                        } else {
                                            // Success and no prompt needed, dismiss the view
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        
                        VStack {
                            Spacer()
                            
                            VStack(spacing: 20) {
                                Text("Scan the barcode on the back of your book")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Text("or")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Button {
                                        showingISBNEntry = true
                                        isISBNFocused = true
                                    } label: {
                                        Text("enter ISBN manually")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .underline()
                                    }
                                }
                            }
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingTotalPagesPrompt) {
                if let pendingBook = viewModel.pendingBook {
                    TotalPagesPromptView(
                        book: pendingBook,
                        onComplete: { updatedBook in
                            viewModel.savePendingBookWithPages(updatedBook)
                        },
                        onCancel: {
                            viewModel.cancelPendingBook()
                        }
                    )
                }
            }
            .onChange(of: viewModel.shouldDismissParentView) { oldValue, shouldDismiss in
                if shouldDismiss {
                    viewModel.shouldDismissParentView = false  // Reset the flag
                    dismiss()
                }
            }
        }
    }
}

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LibraryViewModel
    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = ""
    @State private var currentPage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Form {
                    Section(header: Text("Book Details")) {
                        TextField("Title", text: $title)
                            .padding(.vertical, 8)
                        TextField("Author", text: $author)
                            .padding(.vertical, 8)
                        TextField("Total Pages", text: $totalPages)
                            .keyboardType(.numberPad)
                            .padding(.vertical, 8)
                        TextField("Current Page", text: $currentPage)
                            .keyboardType(.numberPad)
                            .padding(.vertical, 8)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let book = Book(
                            id: UUID(),
                            isbn: "",
                            title: title,
                            author: author,
                            coverURL: nil,
                            currentPage: Int(currentPage) ?? 0,
                            totalPages: Int(totalPages) ?? 0
                        )
                        DataManager.shared.addBook(book)
                        viewModel.loadBooks() // Refresh the books list
                        dismiss()
                    }
                    .disabled(title.isEmpty || author.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CameraScannerView: UIViewControllerRepresentable {
    @Binding var isbn: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()
        
        // Set up camera
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return viewController
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
        } else {
            return viewController
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        // Create scanning frame
        let scanningFrame = UIView()
        scanningFrame.translatesAutoresizingMaskIntoConstraints = false
        scanningFrame.layer.borderColor = UIColor.white.cgColor
        scanningFrame.layer.borderWidth = 1
        scanningFrame.layer.cornerRadius = 8
        viewController.view.addSubview(scanningFrame)
        
        // Add instructions label
        let instructionsLabel = UILabel()
        instructionsLabel.text = "Position the barcode within the frame"
        instructionsLabel.textColor = .white
        instructionsLabel.textAlignment = .center
        instructionsLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(instructionsLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            scanningFrame.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            scanningFrame.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            scanningFrame.widthAnchor.constraint(equalTo: viewController.view.widthAnchor, multiplier: 0.7),
            scanningFrame.heightAnchor.constraint(equalTo: scanningFrame.widthAnchor, multiplier: 0.5),
            
            instructionsLabel.bottomAnchor.constraint(equalTo: scanningFrame.topAnchor, constant: -20),
            instructionsLabel.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor, constant: 20),
            instructionsLabel.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor, constant: -20)
        ])
        
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: CameraScannerView
        
        init(_ parent: CameraScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.isbn = stringValue
                // Don't dismiss here, let the parent view handle the dismiss logic
                // based on whether a total pages prompt is needed
            }
        }
    }
}
