import Foundation
import Supabase
import Combine

final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    
    @Published var isAuthenticated: Bool = false

    private init() {
        let supabaseURL = URL(string: "https://shzxofnfwpsamouvtblh.supabase.co")!
        let supabaseKey = "sb_publishable_Fs5X0Rzqy3DNfaqkW7u0BQ_RDs-FvMF"
        
        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        
        Task {
            await checkSession()
        }
    }

    // Controlla se l'utente è già loggato all'avvio dell'app
    func checkSession() async {
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.isAuthenticated = session != nil
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
    }

    // Funzione per registrare un nuovo utente
    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
        await checkSession()
    }

    // Funzione per effettuare il login
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
        await checkSession()
    }

    // Funzione per effettuare il logout
    func signOut() async throws {
        try await client.auth.signOut()
        await MainActor.run {
            self.isAuthenticated = false
        }
    }
}



// cose da fare:
// 1) Fai test col cellulare
// 2) Migliora la grafica

