//
//  AddExperienceView.swift
//  Travel
//
//  Created by Alessandro Contarini on 01/10/2026.
//

import SwiftUI
import PhotosUI
import Supabase
import PostgREST
import MapKit

struct AddExperienceView: View {
    
    // Per chiudere la schermata modale una volta salvato
    @Environment(\.dismiss) private var dismiss
    
    var onExperienceAdded: () -> Void
    
    var experienceToEdit: Experience? = nil
    
    // Siccome le viste sono immutabili, usiamo state per tenere traccia di quel valore in memoria
    @State private var title = ""
    @State private var price = ""
    @State private var linkMaps = ""
    @State private var partenza = ""
    @State private var km = ""
    @State private var durata = ""
    @State private var selectedTipologia : TipologiaEnum = .moto
    @State private var selectedDifficolta : DifficoltaEnum = .easy
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // ViewModel distinti per evitare conflitti tra le tendine
    @StateObject private var partenzaSearch = LocationSearchViewModel()
    @StateObject private var stepSearch = LocationSearchViewModel()
    @State private var activeSearchIndex: Int? = nil // Traccia quale campo di tappa sta cercando
    
    @State private var isEditingStarted = false
    
    // Gestione delle tappe: la prima è sempre presente (obbligatoria), fino a un massimo di 5
    @State private var stepsArray: [String] = [""]
    
    // Gestione della selezione dell'immagine da locale
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    // Stato per gestire eventuali messaggi di errore a schermo se mancano campi
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Messaggio di errore visivo se si prova a salvare con campi vuoti
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }

                Section(header: Text("Tipologia di Esperienza")) {
                    Picker("Tipologia", selection: $selectedTipologia) {
                        ForEach(TipologiaEnum.allCases) { tipo in
                            Text(tipo.rawValue).tag(tipo).font(.headline)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                 
                Section(header: Text("Informazioni Generali *")) {
                    TextField("Titolo", text: $title)
                    TextField("Prezzo (€)", text: $price)
                        .keyboardType(.decimalPad)
                        //_ è il valore vecchio di price (ignorato), mentre in separa i parametri dal corpo
                        .onChange(of: price){ _, newValue in
                            price = newValue.replacingOccurrences(of: ",", with: ".")
                        }
                }
                 
                Section(header: Text("Seleziona la difficoltà")) {
                    Picker("Difficoltà", selection: $selectedDifficolta) {
                        ForEach(DifficoltaEnum.allCases) { diff in
                            Text(diff.rawValue).tag(diff).font(.headline)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Dettagli Percorso *")) {
                    // Campo di testo per la partenza con ricerca dedicata
                    TextField("Città / Luogo di Partenza", text: $partenza)
                        .onChange(of: partenza) { _, newValue in
                            if isEditingStarted {
                                activeSearchIndex = nil // Azzeriamo il focus delle tappe
                                partenzaSearch.updateQuery(query: newValue)
                            }
                        }
                     
                    // Lista a tendina per la partenza (Risolto con Button per il singolo click)
                    if isEditingStarted && activeSearchIndex == nil && !partenzaSearch.searchResults.isEmpty && !partenza.isEmpty {
                        ForEach(partenzaSearch.searchResults.prefix(5), id: \.self) { result in
                            Button {
                                partenza = "\(result.title), \(result.subtitle)"
                                partenzaSearch.searchResults = []
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .foregroundColor(.primary)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle()) // Rende cliccabile tutto lo spazio bianco della riga
                            }
                            .buttonStyle(.plain)
                        }
                    }
                     
                    TextField("Chilometri (km)", text: $km)
                        .keyboardType(.decimalPad)
                        .onChange(of: km){ _, newValue in
                            km = newValue.replacingOccurrences(of: ",", with: ".")
                        }
                    TextField("Durata (ore)", text: $durata)
                        .keyboardType(.decimalPad)
                        .onChange(of: durata){ _, newValue in
                            durata = newValue.replacingOccurrences(of: ",", with: ".")
                        }
                }

                Section(header: Text("Immagine di Copertina")) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text(selectedImageData == nil ? "Seleziona foto dalla galleria" : "Foto selezionata con successo")
                        }
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }
                }

                Section(header: Text("Posizione")) {
                    TextField("Link Google Maps (opzionale)", text: $linkMaps)
                }

                // Sezione tappe con ricerca isolata per ogni singola riga
                Section(header: Text("Principali tappe"), footer: Text("La prima tappa è obbligatoria. Puoi aggiungerne fino ad altre 4 opzionali.")) {
                    ForEach(0..<stepsArray.count, id: \.self) { index in
                        VStack(alignment: .leading) {
                            HStack {
                                TextField(index == 0 ? "Tappa 1 (Obbligatoria)" : "Tappa \(index + 1) (Opzionale)", text: $stepsArray[index])
                                    .onChange(of: stepsArray[index]) { _, newValue in
                                        if isEditingStarted {
                                            activeSearchIndex = index // Impostiamo quale indice sta scrivendo
                                            stepSearch.updateQuery(query: newValue)
                                        }
                                    }
                                 
                                if stepsArray.count > 1 {
                                    Button(action: {
                                        stepsArray.remove(at: index)
                                        if activeSearchIndex == index {
                                            activeSearchIndex = nil
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                             
                            // Tendina suggerimenti attiva SOLO per questa specifica tappa (Risolto con Button)
                            if isEditingStarted && activeSearchIndex == index && !stepSearch.searchResults.isEmpty && !stepsArray[index].isEmpty {
                                ForEach(stepSearch.searchResults.prefix(5), id: \.self) { result in
                                    Button {
                                        stepsArray[index] = "\(result.title), \(result.subtitle)"
                                        stepSearch.searchResults = []
                                        activeSearchIndex = nil
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                                .foregroundColor(.primary)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle()) // Rende cliccabile tutto lo spazio bianco della riga
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                     
                    if stepsArray.count < 5 {
                        Button(action: {
                            stepsArray.append("")
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Aggiungi altra tappa")
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately) // Chiude la tastiera subito al primo tocco
            .navigationTitle(experienceToEdit == nil ? "Nuova esperienza" : "Modifica esperienza")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        Task {
                            await saveExperience()
                        }
                    }
                }
            }
             
            .alert("Azione non consentita", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
             
            .onAppear() {
                if let exp = experienceToEdit {
                    title = exp.title
                    price = String(exp.price)
                    linkMaps = exp.link_maps ?? ""
                    partenza = exp.partenza
                    km = String(exp.km)
                    durata = String(exp.durata)
                    selectedTipologia = exp.type
                    selectedDifficolta = exp.difficolta

                    if !exp.steps.isEmpty {
                        stepsArray = exp.steps
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isEditingStarted = true
                }
            }
        }
    }
         
    // Funzione asincrona di validazione e salvataggio
    private func saveExperience() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedPartenza = partenza.trimmingCharacters(in: .whitespaces)
        let cleanedSteps = stepsArray.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
         
        if trimmedTitle.isEmpty || price.isEmpty || trimmedPartenza.isEmpty || km.isEmpty || durata.isEmpty {
            await MainActor.run {
                errorMessage = "Compila tutti i campi obbligatori (Titolo, Prezzo, Partenza, Km, Durata)."
            }
            return
        }
         
        if cleanedSteps.isEmpty {
            await MainActor.run {
                errorMessage = "Inserisci almeno la prima tappa obbligatoria."
            }
            return
        }
         
        var locationsToVerify = [trimmedPartenza]
        locationsToVerify.append(contentsOf: cleanedSteps)
         
        for location in locationsToVerify {
            if !location.contains(",") {
                await MainActor.run {
                    self.alertMessage = "Il luogo '\(location)' non è valido. Seleziona un indirizzo ufficiale dai suggerimenti della lista."
                    self.showAlert = true
                }
                return
            }
             
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = location
            let search = MKLocalSearch(request: request)
             
            do {
                let response = try await search.start()
                if response.mapItems.isEmpty {
                    await MainActor.run {
                        self.alertMessage = "Il luogo '\(location)' non esiste o non è stato trovato."
                        self.showAlert = true
                    }
                    return
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Impossibile verificare il luogo '\(location)'."
                    self.showAlert = true
                }
                return
            }
        }
         
        let priceDouble = Double(price) ?? 0.0
        let kmDouble = Double(km) ?? 0.0
        let durataDouble = Double(durata) ?? 0.0
         
        var imageNameFinal = experienceToEdit?.image_name ?? "default.jpg"
         
        if let imageData = selectedImageData {
            let uniqueFileName = "\(UUID().uuidString).jpg"
            do {
                _ = try await SupabaseManager.shared.client.storage
                    .from("experience-images")
                    .upload(
                        path: uniqueFileName,
                        file: imageData,
                        options: Storage.FileOptions(contentType: "image/jpeg", upsert: true)
                    )
                imageNameFinal = uniqueFileName
            } catch {
                print("Errore durante l'upload dell'immagine: \(error)")
                await MainActor.run {
                    errorMessage = "Errore durante il caricamento dell'immagine."
                }
                return
            }
        }

        let currentUserId = SupabaseManager.shared.client.auth.currentSession?.user.id
         
        struct NewExperienceData: Encodable {
            let title: String
            let price: Double
            let image_name: String
            let link_maps: String
            let partenza: String
            let km: Double
            let durata: Double
            let steps: [String]
            let type: String
            let difficolta: String
            let user_id: UUID?
        }

        let newExp = NewExperienceData(
            title: trimmedTitle,
            price: priceDouble,
            image_name: imageNameFinal,
            link_maps: linkMaps,
            partenza: trimmedPartenza,
            km: kmDouble,
            durata: durataDouble,
            steps: cleanedSteps,
            type: selectedTipologia.rawValue,
            difficolta: selectedDifficolta.rawValue,
            user_id: currentUserId
        )

        do {
            if let expToEdit = experienceToEdit {
                if expToEdit.user_id != nil && expToEdit.user_id != currentUserId {
                    await MainActor.run {
                        self.alertMessage = "Non hai i permessi per modificare questa esperienza."
                        self.showAlert = true
                    }
                    return
                }
                 
                let id = expToEdit.id
                try await SupabaseManager.shared.client
                    .from("Experience")
                    .update(newExp)
                    .eq("id", value: id)
                    .execute()
                print("Modifica riuscita con successo!")
            } else {
                try await SupabaseManager.shared.client
                    .from("Experience")
                    .insert(newExp)
                    .execute()
                print("Inserimento riuscito con successo!")
            }
            await MainActor.run {
                onExperienceAdded()
                dismiss()
            }
        } catch {
            print("Errore durante il salvataggio dei dati su Supabase: \(error)")
            await MainActor.run {
                errorMessage = "Errore di salvataggio nel database: \(error.localizedDescription)"
            }
        }
    }
}
