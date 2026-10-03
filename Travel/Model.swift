//
//  Model.swift
//  Travel
//
//  Created by Alessandro Contarini on 28/09/2026.
// PW db supabase Alebilly3?12! => Account GH

import Foundation
import Storage
import Supabase
import PostgREST

struct Experience: Identifiable, Codable { // ogni experience è unica, Codable = traduce obj Swift in JSON
    let id: UUID // il DB assegnerà un ID (stringa o UUID), per ora va benissimo UUID
    let title: String
    let price: Double
    let image_name: String
    let partenza: String
    let link_maps: String?
    let km: Double
    let durata: Double
    let steps: [String]
    let type: TipologiaEnum
    let difficolta: DifficoltaEnum
    let user_id: UUID?
    
    
    var publicImageURL: URL? {
        guard !image_name.isEmpty else { return nil }
        
        let url = try? SupabaseManager.shared.client.storage
            .from("experience-images") // Sostituisci con il nome esatto del tuo bucket su Supabase
            .getPublicURL(path: image_name)
            
        return url
    }
    
    var mapsURL: URL? {
        guard let link = link_maps, !link.isEmpty else { return nil }
        return URL(string:link)
    }
    
    
}


enum TipologiaEnum: String, Codable, CaseIterable, Identifiable {
    case trekking = "🚶"
    case moto = "🏍️"
    case bici = "🚴🏻"
    
    var id: String { self.rawValue } //self.rawValue restituisce il valore letterale associato all'enum
}


enum DifficoltaEnum: String, Codable, CaseIterable, Identifiable {
    case easy = "semplice"
    case medium = "medio"
    case hard = "difficile"
    
    var id: String { self.rawValue }
}





