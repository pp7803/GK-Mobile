//
//  ContentView.swift
//  PPNote
//
//  Created by Phát Phạm on 22/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        NotesListView()
            .environment(\.managedObjectContext, coreDataManager.context)
    }
}

#Preview {
    ContentView()
}
