import SwiftUI
import CoreData
import Combine

struct NotesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
        predicate: NSPredicate(format: "tempDelete == NO"),
        animation: .default)
    private var notes: FetchedResults<Note>
    
    @State private var showingNewNote = false
    @State private var showingDeletedNotes = false
    @State private var showingLogin = false
    @State private var showingAIPrompt = false
    @State private var searchText = ""
    @State private var isSelectionMode = false
    @State private var selectedNotes = Set<NSManagedObjectID>()
    @State private var refreshToken = UUID()
    @State private var showSyncToast = false
    @State private var syncToastMessage = ""
    @State private var syncToastIcon = "checkmark.circle.fill"
    @State private var syncToastColor = Color.green
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return Array(notes)
        } else {
            return notes.filter { note in
                note.title?.localizedCaseInsensitiveContains(searchText) == true ||
                note.content?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                NavigationLink(
                    destination: UnifiedNoteEditView(),
                    isActive: $showingNewNote
                ) {
                    EmptyView()
                }
                .hidden()
                
                mainContent
                    .id(refreshToken)
            }
            .navigationTitle(isSelectionMode ? "Đã chọn \(selectedNotes.count) ghi chú" : "PPNote")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Hủy") {
                            exitSelectionMode()
                        }
                    } else {
                        leadingToolbarMenu
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        deleteSelectedButton
                    } else {
                        trailingToolbarButtons
                    }
                }
            }
        }
        .sheet(isPresented: $showingDeletedNotes) {
            DeletedNotesView()
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
        }
        .sheet(isPresented: $showingAIPrompt) {
            AIPromptView()
        }
        .onAppear {
            setupView()
            Task {
                if authManager.isLoggedIn {
                    await syncManager.forceSync()
                } else {
                    await refreshNotes()
                }
            }
            syncManager.setAutoSyncEnabled(true)
        }
        .onDisappear {
            syncManager.setAutoSyncEnabled(false)
        }
        .onChange(of: authManager.isLoggedIn, perform: handleLoginChange)
        .onChange(of: networkManager.isConnected, perform: handleNetworkChange)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            handleAppForeground()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotesUpdated"))) { _ in
            refreshNotesListUI()
        }
        .onReceive(syncManager.$lastSyncDate.compactMap { $0 }) { _ in
            refreshNotesListUI()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncSuccess"))) { notification in
            handleSyncSuccess(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncFailure"))) { notification in
            handleSyncFailure(notification)
        }
        .toast(
            isShowing: $showSyncToast,
            message: syncToastMessage,
            icon: syncToastIcon,
            backgroundColor: syncToastColor
        )
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            StatusBarView(
                networkManager: networkManager,
                syncManager: syncManager,
                authManager: authManager
            )
            searchBar
            notesListContent
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Tìm kiếm ghi chú...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var notesListContent: some View {
        ScrollView {
            if filteredNotes.isEmpty {
                EmptyStateView()
                    .padding(.top, 60)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(filteredNotes, id: \.id) { note in
                        noteRow(for: note)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .refreshable {
            await refreshNotes()
        }
    }
    
    private func noteRow(for note: Note) -> some View {
        Group {
            if isSelectionMode {
                HStack {
                    Button(action: { toggleNoteSelection(note) }) {
                        Image(systemName: selectedNotes.contains(note.objectID) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedNotes.contains(note.objectID) ? .blue : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    NoteCardView(note: note, useServerTimestamps: authManager.isLoggedIn)
                        .opacity(0.7)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleNoteSelection(note)
                }
            } else {
                NavigationLink(destination: UnifiedNoteEditView(note: note)) {
                    NoteCardView(note: note, useServerTimestamps: authManager.isLoggedIn)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(action: { deleteNote(note) }) {
                        Label("Xóa", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                    
                    Button(action: { duplicateNote(note) }) {
                        Label("Sao chép", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
    
    private var leadingToolbarMenu: some View {
        Menu {
            Button(action: { enterSelectionMode() }) {
                Label("Chọn nhiều", systemImage: "checkmark.circle")
            }
            
            Divider()
            
            Button(action: { showingDeletedNotes = true }) {
                Label("Đã xóa gần đây", systemImage: "trash")
            }
            
            if authManager.isLoggedIn {
                Button(action: { Task { await syncManager.forceSync() } }) {
                    Label("Đồng bộ ngay", systemImage: "arrow.clockwise")
                }
                
                Divider()
                
                Button(action: authManager.logout) {
                    Label("Đăng xuất", systemImage: "person.crop.circle.badge.minus")
                }
            } else {
                Button(action: { showingLogin = true }) {
                    Label("Đăng nhập", systemImage: "person.crop.circle.badge.plus")
                }
            }
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.title2)
        }
    }
    
    private var trailingToolbarButtons: some View {
        HStack(spacing: 8) {
            aiButton
            newNoteButton
        }
    }
    
    private var aiButton: some View {
        Button(action: { showingAIPrompt = true }) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var newNoteButton: some View {
        Button(action: { showingNewNote = true }) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var deleteSelectedButton: some View {
        Button(action: { deleteSelectedNotes() }) {
            Text("Xóa (\(selectedNotes.count))")
                .foregroundColor(.red)
                .fontWeight(.semibold)
        }
        .disabled(selectedNotes.isEmpty)
    }
    
    private func setupView() {
        coreDataManager.cleanupOldDeletedNotes()
        coreDataManager.debugPrintAllData()
    }
    
    private func handleLoginChange(_ isLoggedIn: Bool) {
        if isLoggedIn && showingLogin {
            showingLogin = false
        }
    }
    
    private func handleNetworkChange(_ isConnected: Bool) {
        if isConnected && authManager.isLoggedIn {
            Task {
                await syncManager.syncIfNeeded()
            }
        }
    }
    
    private func handleAppForeground() {
        if networkManager.isConnected && authManager.isLoggedIn {
            Task {
                await syncManager.syncIfNeeded()
            }
        }
    }
    
    private func deleteNote(_ note: Note) {
        coreDataManager.deleteNote(note)
    }

    private func refreshNotes() async {
        if authManager.isLoggedIn {
            await syncManager.forceSync()
        } else {
            await MainActor.run {
                viewContext.refreshAllObjects()
            }
        }
    }
    
    private func duplicateNote(_ note: Note) {
        let newTitle = "Copy of \(note.title ?? "Untitled")"
        coreDataManager.createNote(
            title: newTitle,
            content: note.content ?? "",
            isDraft: true
        )
    }
    
    private func toggleNoteSelection(_ note: Note) {
        if selectedNotes.contains(note.objectID) {
            selectedNotes.remove(note.objectID)
        } else {
            selectedNotes.insert(note.objectID)
        }
    }
    
    private func enterSelectionMode() {
        isSelectionMode = true
        selectedNotes.removeAll()
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedNotes.removeAll()
    }
    
    private func deleteSelectedNotes() {
        for noteID in selectedNotes {
            do {
                if let note = try viewContext.existingObject(with: noteID) as? Note {
                    coreDataManager.deleteNote(note)
                }
            } catch {
                print("Error fetching note for deletion: \(error)")
            }
        }
        exitSelectionMode()
    }
    
    private func refreshNotesListUI() {
        DispatchQueue.main.async {
            viewContext.perform {
                viewContext.refreshAllObjects()
            }
            refreshToken = UUID()
        }
    }
    
    // MARK: - Sync Notifications
    
    private func handleSyncSuccess(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            syncToastMessage = message
            syncToastIcon = "checkmark.circle.fill"
            syncToastColor = .green
            withAnimation {
                showSyncToast = true
            }
        }
    }
    
    private func handleSyncFailure(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            syncToastMessage = message
            syncToastIcon = "exclamationmark.triangle.fill"
            syncToastColor = .red
            withAnimation {
                showSyncToast = true
            }
        }
    }
}

// MARK: - Preview
