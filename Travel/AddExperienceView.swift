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

struct AddExperienceView: View {
    
    // Per chiudere la schermata modale una volta salvato
    @Environment(\.dismiss) private var dismiss //recupera dall'ambiente la proprietà di chiusura nativa
    
    var onExperienceAdded: () -> Void //Closure => funzione passata come parametro, in attesa di essere eseguita. Vista quindi dal genitore (ContentView)
    
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
    
    // Gestione delle tappe: la prima è sempre presente (obbligatoria), fino a un massimo di 5
    @State private var stepsArray: [String] = [""]
    
    // Gestione della selezione dell'immagine da locale
    @State private var selectedItem: PhotosPickerItem? = nil // gestisce l'oggetto multimediale
    @State private var selectedImageData: Data? = nil // converte l'oggetto in dati grezzi da caricare su Supabase
    
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
                    .pickerStyle(.segmented) // Oppure .menu a seconda dello stile che preferisci
                }
                
                Section(header: Text("Informazioni Generali *")) {
                    TextField("Titolo", text: $title)
                    TextField("Prezzo", text: $price)
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
                    TextField("Città / Luogo di Partenza", text: $partenza)
                    TextField("Chilometri (km)", text: $km)
                    TextField("Durata (ore)", text: $durata)
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

                // Sezione tappe: 1 obbligatoria, fino a 5 opzionali in totale
                Section(header: Text("Principali tappe"), footer: Text("La prima tappa è obbligatoria. Puoi aggiungerne fino ad altre 4 opzionali.")) {
                    ForEach(0..<stepsArray.count, id: \.self) { index in
                        HStack {
                            TextField(index == 0 ? "Tappa 1 (Obbligatoria)" : "Tappa \(index + 1) (Opzionale)", text: $stepsArray[index])
                            
                            // Permettiamo di rimuovere la tappa solo se ce n'è più di una (lasciando sempre almeno la prima)
                            if stepsArray.count > 1 {
                                Button(action: {
                                    stepsArray.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    // Mostra il pulsante di aggiunta finché non si raggiungono 5 tappe
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
            
            .onAppear() { // .onAppear è un modificatore che viene eseguito appena viene visualizzata la schermata
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
            }
        
        }
    }
        
    // Funzione asincrona di validazione e salvataggio
    private func saveExperience() async {
        // 1. VALIDAZIONE CAMPI OBBLIGATORI
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedPartenza = partenza.trimmingCharacters(in: .whitespaces)
        let cleanedSteps = stepsArray.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        if trimmedTitle.isEmpty || price.isEmpty || trimmedPartenza.isEmpty || km.isEmpty || durata.isEmpty {
            await MainActor.run {
                errorMessage = "Compila tutti i campi obbligatori (Titolo, Descrizione, Prezzo, Partenza, Km, Durata)."
            }
            return
        }
        
        // 2. VALIDAZIONE TAPPA OBBLIGATORIA (la prima non deve essere vuota)
        if cleanedSteps.isEmpty {
            await MainActor.run {
                errorMessage = "Inserisci almeno la prima tappa obbligatoria."
            }
            return
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
        
        struct NewExperienceData: Encodable { // Encodable serve a impacchettare tutte le variabili in JSON pronto per il db
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
        
        let currentUser = SupabaseManager.shared.client.auth.currentSession?.user

        do {
            if let expToEdit = experienceToEdit{
                // CONTROLLO DI SICUREZZA
                if expToEdit.user_id != currentUserId {
                    await MainActor.run {
                        self.alertMessage = "Non hai i permessi per modificare questa esperienza."
                        self.showAlert = true
                    }
                    return
                }
                
                //Modifica UPDATE
                let id = expToEdit.id
                try await SupabaseManager.shared.client
                    .from("Experience")
                    .update(newExp)
                    .eq("id", value: id)
                    .execute()
                print("Modifica riuscita con successo!")
            } else{
                // Inserimento INSERT
                try await SupabaseManager.shared.client
                    .from("Experience")
                    .insert(newExp)
                    .execute()
                print("Inserimento riuscito con successo!")
            }
            await MainActor.run {
                onExperienceAdded() // codice fornito dal contentView quando apre il modale
                dismiss() //chiude la schermata modale
            }
        } catch {
            print("Errore durante il salvataggio dei dati su Supabase: \(error)")
            await MainActor.run {
                errorMessage = "Errore di salvataggio nel database: \(error.localizedDescription)"
            }
        }
    }
}
