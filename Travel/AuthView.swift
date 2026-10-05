//
//  AuthView.swift
//  Travel
//
//  Created by Alessandro Contarini on 03/10/2026.
//

import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false // Alterna tra Login e Registrazione
    @State private var errorMessage: String? = nil
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(isSignUp ? "Crea Account" : "Benvenuto")
                    .font(.largeTitle)
                    .bold()
                
                Text(isSignUp ? "Registrati per iniziare a condividere i tuoi viaggi" : "Accedi per gestire le tue esperienze")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Button(action: {
                    Task {
                        await handleAuthAction()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(isSignUp ? "Registrati" : "Accedi")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .disabled(email.isEmpty || password.isEmpty)

                Button(action: {
                    isSignUp.toggle()
                }) {
                    Text(isSignUp ? "Hai già un account? Accedi" : "Non hai un account? Registrati")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                .padding(.top)

                Spacer()
            }
            .padding(.top, 50)
        }
    }

    private func handleAuthAction() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if isSignUp {
                try await SupabaseManager.shared.signUp(email: email, password: password)
                // Se arrivi qua, la registrazione è riuscita:
                await MainActor.run {
                    isSignUp = false // riporta l'interfaccia alla modalità login
                    password = "" // pulisce la pw per sicurezza
                }
            } else {
                try await SupabaseManager.shared.signIn(email: email, password: password)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
}
