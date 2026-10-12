# myTravel 🌍🏍️

**myTravel** è un'applicazione nativa iOS sviluppata in **SwiftUI** e potenziata da **Supabase**, progettata per tracciare, organizzare e condividere esperienze di viaggio e itinerari all'aperto (moto, bici, escursioni a piedi).

---

## 🚀 Caratteristiche Principali

* **Autenticazione Sicura:** Gestione completa degli utenti tramite Supabase Auth (Login, Registrazione, Logout e **Recupero Password** integrato con Deep Linking).
* **Gestione Viaggi ed Esperienze (CRUD):** 
  * Creazione, visualizzazione e cancellazione protetta (ogni utente può eliminare solo i propri viaggi).
  * Aggiunta di tappe multiple con autocompletamento geografico basato su **MapKit**.
* **Fondi e Filtri Avanzati:** 
  * Filtri di ricerca indipendenti per **Tipologia** (Moto, Bici, A piedi, ecc.) e **Difficoltà**.
* **Storage Multimediale:** Sincronizzazione in tempo reale delle immagini di copertina e dei dettagli tramite i bucket di Supabase Storage.
* **UI/UX Nativa:** Interfaccia moderna e pulita ottimizzata per le ultime versioni di iOS, con componenti nativi come liste dinamiche, fogli modali (`sheet`) e menu contestuali.

---

## 🛠️ Stack Tecnologico

* **Frontend:** SwiftUI (iOS 16+)
* **Backend & Database:** Supabase (PostgreSQL, Auth, Storage)
* **Framework di Mappa e Ricerca:** MapKit & CoreLocation
* **Linguaggio:** Swift

---

## ⚙️ Configurazione e Avvio

1. Clona il repository:
   ```bash
   git clone https://github.com/alessandrocontarini/Travel.git
   ```
2. Apri il progetto in **Xcode**.
3. Configura le credenziali di Supabase all'interno del file di inizializzazione (`SupabaseManager`).
4. Configura l'**URL Scheme** (`mytravel`) nelle impostazioni del Target (tab *Info*) per abilitare il corretto reindirizzamento del recupero password.
5. Seleziona un simulatore iOS e compila l'applicazione (`Cmd + R`).

---

## 📱 Anteprima e Funzionalità
L'applicazione offre un flusso utente fluido che unisce la pianificazione cartografica alla condivisione social dei percorsi, garantendo sicurezza dei dati tramite politiche di Row Level Security (RLS) su Supabase.
