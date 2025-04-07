//
//  SignInView.swift
//  markapp
//
//  Created by Eason Tang on 4/5/25.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)
                
                Text("Welcome to MarkApp")
                    .font(.largeTitle)
                    .bold()
                
                Text(isSignUp ? "Create an account to get started" : "Sign in to your account")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 5)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding(.horizontal, 5)
                }
                
                if !authManager.isConnected {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                        Text("No internet connection")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    Task {
                        await authenticate()
                    }
                }) {
                    if authManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.5))
                            .cornerRadius(12)
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty || !authManager.isConnected)
                .opacity(!authManager.isConnected ? 0.5 : 1.0)
                
                Button(action: {
                    isSignUp.toggle()
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer().frame(height: 40)
            }
            .padding()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func authenticate() async {
        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password)
                alertTitle = "Account Created"
                alertMessage = "Your account has been created successfully. You can now sign in."
            } else {
                try await authManager.signIn(email: email, password: password)
                alertTitle = "Sign In"
                alertMessage = "You have successfully signed in."
            }
            showAlert = true
        } catch {
            alertTitle = isSignUp ? "Sign Up Failed" : "Sign In Failed"
            
            // Check for specific error types
            if let nsError = error as NSError? {
                // Handle network connection has no local endpoint error
                if nsError.localizedDescription.contains("nw_connection_copy_connected_local_endpoint") ||
                   nsError.localizedDescription.contains("Connection has no local endpoint") {
                    alertMessage = "Network connection issue detected. Please check your internet connection and try again in a few moments."
                }
                else if nsError.domain == "AuthManager" && nsError.code == -1009 {
                    alertMessage = nsError.localizedDescription
                } 
                else if nsError.code == NSURLErrorNotConnectedToInternet || 
                        nsError.code == NSURLErrorNetworkConnectionLost ||
                        nsError.localizedDescription.contains("network") ||
                        nsError.localizedDescription.contains("connection") {
                    alertMessage = "The network connection was lost. Please check your internet connection and try again."
                } 
                else {
                    alertMessage = error.localizedDescription
                }
            } else {
                alertMessage = error.localizedDescription
            }
            
            showAlert = true
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthManager())
}
