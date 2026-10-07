//
//  LocationSearchViewModel.swift
//  Travel
//
//  Created by Alessandro Contarini on 05/10/2026.
//  Interroga le mappe di Apple in base a quello che digiti


import MapKit
import Combine

class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    private var completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        // Abilita sia gli indirizzi fisici che i punti di interesse (bar, rifugi, monumenti, ecc.)
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func updateQuery(query: String) {
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Errore ricerca luoghi: \(error.localizedDescription)")
    }
}

