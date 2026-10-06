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
    @State private var selectedTypeFilter: TipologiaEnum? = nil
    @State private var selectedDifficultyFilter: DifficoltaEnum? = nil
    
    // logica di filtraggio indipendente
    var filteredExperiences: [Experience] {
        return experiences.filter { exp in
            // Filtro per tipologia (se è impostato, deve corrispondere)
            let matchesType = (selectedTypeFilter == nil || exp.type == selectedTypeFilter)
             
            // Filtro per difficoltà (se è impostato, deve corrispondere)
            let matchesDifficulty = (selectedDifficultyFilter == nil || exp.difficolta == selectedDifficultyFilter)
             
            return matchesType && matchesDifficulty
        }
    }
    

    var body: some View {
        NavigationStack { //contenitore di navigazione std di iOS
             
            VStack { // contenitore verticale condizionale
                if let errorMessage { //verifica je è nil
                    Text("Errore: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if experiences.isEmpty {
                    ProgressView("Caricamento esperienze...")
                } else {
                    // BARRA DEI FILTRI
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Menu(selectedTypeFilter?.rawValue ?? "Tutte le tipologie") {
                                Button("Tutte le tipologie") { selectedTypeFilter = nil }
                                ForEach(TipologiaEnum.allCases) { tipo in
                                    Button(tipo.rawValue) { selectedTypeFilter = tipo }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedTypeFilter == nil ? .secondary : .blue)
                            
                            Menu(selectedDifficultyFilter?.rawValue ?? "Tutte le difficoltà") {
                                Button("Tutte le difficoltà") { selectedDifficultyFilter = nil }
                                ForEach(DifficoltaEnum.allCases) { diff in
                                    Button(diff.rawValue) { selectedDifficultyFilter = diff }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedDifficultyFilter == nil ? .secondary : .blue)
                            
                            if selectedTypeFilter != nil || selectedDifficultyFilter != nil {
                                Button(action: {
                                    selectedTypeFilter = nil
                                    selectedDifficultyFilter = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                    
                    List{
                        // Gestione Backend con lista filtrata
                        ForEach(filteredExperiences){experience in
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
             
            .navigationTitle("Esplora Esperienze")
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
    func fetchExperiences() async {
        do {
            let response: [Experience] = try await SupabaseManager.shared.client
                .from("Experience")
                .select()
                .execute()
                .value
             
            await MainActor.run {
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
    // Funzione per eliminare l'esperienza dal db di Supabase (solo se è tua)
    private func deleteExperience(at offsets: IndexSet) {
        Task {
            guard let currentUserId = SupabaseManager.shared.client.auth.currentSession?.user.id else {
                return
            }

            for index in offsets {
                let experienceToDelete: Experience = experiences[index]
                 
                if experienceToDelete.user_id != currentUserId {
                    print("Tentativo di eliminazione bloccato: non sei il proprietario di questa esperienza.")
                    await MainActor.run {
                        self.alertMessage = "Non hai i permessi per modificare questa esperienza"
                        self.showAlert = true
                    }
                    continue
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
             
            await fetchExperiences()
        }
    }
}

#Preview {
    ContentView()
}
