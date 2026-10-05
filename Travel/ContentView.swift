//
//  ContentView.swift
//  Travel
//
//  Created by Alessandro Contarini on 28/09/2026.
//  ContentView è la view principale.
//

import SwiftUI
import Supabase
import PostgREST

struct ContentView: View {
    @State private var experiences: [Experience] = [] //State è una proprietà di stato reattiva
    @State private var errorMessage: String? = nil
    @State private var showingAddView = false // stato per aprire/chiudere il modulo
    @State private var showAlert = false
    @State private var alertMessage = ""
    

    var body: some View {
        NavigationStack { //contenitore di navigazione std di iOS
            
            VStack { // contenitore verticale condizionale
                if let errorMessage { //verifica se è nil
                    Text("Errore: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if experiences.isEmpty {
                    ProgressView("Caricamento esperienze...")
                } else {
                    List{
                        // Gestione Backend
                        ForEach(experiences){experience in
                            // Qui dentro puoi disporre gli elementi in orizzontale come preferisci!
                            NavigationLink(destination: ExperienceDetailView(experience: experience){
                                Task{
                                    await fetchExperiences()
                                }
                            }) {
                                
                                HStack(alignment: .center, spacing: 18) {
                                    Image(systemName: "map.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(experience.title) \(experience.type.rawValue)")
                                            .font(.headline)
                                        Text("Difficoltà: \(experience.difficolta.rawValue)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Prezzo: €\(experience.price, specifier: "%.2f")")
                                            .font(.footnote)
                                            .bold()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteExperience)
                    }
                }
            }
            .alert("Azione non consentita", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            
            .navigationTitle("Esplora Viaggi")
            .toolbar{
                // Gestione Frontend del VStack
                // 1. BOTTONE MODIFICA
                ToolbarItem(placement: .navigationBarLeading){
                    EditButton()
                }
                
                // 2. BOTTONE LOGOUT
                ToolbarItem(placement: .navigationBarLeading){
                    Button(action: {
                        Task{
                            do{
                                try await SupabaseManager.shared.signOut()
                            }catch{
                                print ("Errore durante il logout: \(error.localizedDescription)")
                            }
                        }
                    }){
                        Image(systemName: "rectangle.portrait.and.arrow.right").foregroundColor(.red)
                    }
                }
                
                // 3. BOTTONE AGGIUNGI
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddView = true
                    }){
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddView) {
                AddExperienceView{
                    //quello che c'è qua dentro è il contenuto che finisce in onExperienceAdd
                    Task{
                        await fetchExperiences()
                    }
                }
            }
            
            
            .task {
                await fetchExperiences() // avvia l'esecuzione asincrona
            }
        }
    }

    // =====================================================================
    // funzione asincrona per aggiornare la vista delle esperienze
    func fetchExperiences() async { //funzione asincrona
        do {
            let response: [Experience] = try await SupabaseManager.shared.client
                .from("Experience")
                .select()
                .execute()
                .value
            
            await MainActor.run { //garantisce che l'assegnazione a experiences avvenga dal thread principale, perché le chiamate di rete avvengono in bg
                self.experiences = response
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            print("Errore durante il fetch da Supabase: \(error)")
        }
    }
    
    // =====================================================================
    //funzione per eliminare l'esperienza dal db di Supabase
    // =====================================================================
    // Funzione per eliminare l'esperienza dal db di Supabase (solo se è tua)
    private func deleteExperience(at offsets: IndexSet) {
        Task {
            // Recuperiamo l'ID dell'utente attualmente loggato
            guard let currentUserId = SupabaseManager.shared.client.auth.currentSession?.user.id else {
                return
            }

            for index in offsets {
                let experienceToDelete: Experience = experiences[index]
                
                // CONTROLLO DI SICUREZZA: se l'ID non coincide, blocchiamo l'eliminazione
                if experienceToDelete.user_id != currentUserId {
                    print("Tentativo di eliminazione bloccato: non sei il proprietario di questa esperienza.")
                    await MainActor.run {
                        self.alertMessage = "Non hai i permessi per modificare questa esperienza"
                        self.showAlert = true
                    }
                    continue // Salva e salta questo elemento senza cancellarlo
                }

                let id = experienceToDelete.id
               
                do {
                    try await SupabaseManager.shared.client
                        .from("Experience")
                        .delete()
                        .eq("id", value: id)
                        .execute()
                   
                    print("Esperienza eliminata con successo")
                } catch {
                    print("Errore durante l'eliminazione su Supabase: \(error)")
                }
            }
            
            await fetchExperiences() // Ricarica la lista aggiornata
        }
    }
}
    

#Preview {
    ContentView()
}


// NB: In SwiftUI l'interfaccia utente si ridisegna in base ai cambiamenti di stato, quindi serve:
//      1) Una variabile di stato che faccia da interruttore
//      2) Il modificatore .alert() attaccato alla vista
//      3) Il cambio di stato quandi vuoi mostrarlo
