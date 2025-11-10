import Foundation
import CoreData
import Combine
import UserNotifications

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private static let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private let coreDataManager = CoreDataManager.shared
    private let apiService = APIService.shared
    private let networkManager = NetworkManager.shared
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var isViewingNote = false // Track if user is currently viewing/editing a note
    
    // Track notes currently being synced to prevent duplicates
    private var notesCurrentlySyncing = Set<String>()
    private let syncQueue = DispatchQueue(label: "sync.queue", qos: .utility)
    private var isAutoSyncEnabled = false
    
    private var isLoggedIn: Bool {
        return AuthManager.shared.isLoggedIn
    }
    
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        restoreLastSyncDate()
        setupAutoSync()
        setupNetworkObserver()
    }

    private func restoreLastSyncDate() {
        if let storedDate = coreDataManager.getCurrentUser()?.lastSyncTime {
            lastSyncDate = storedDate
            print("SyncManager: Restored last sync time from storage: \(storedDate)")
        }
    }
    
    private func setupAutoSync() {
        // Auto sync every 30 seconds when enabled, connected, and logged in
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.autoSync()
            }
        }
    }
    
    private func setupNetworkObserver() {
        // Sync when network becomes available
        NotificationCenter.default.addObserver(
            forName: .init("NetworkConnected"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.syncIfNeeded()
            }
        }
        
        // Also observe network status changes directly
        networkManager.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    Task {
                        await self?.syncIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func autoSync() async {
        guard !isSyncing,
              isAutoSyncEnabled,
              networkManager.isConnected,
              isLoggedIn,
              !isViewingNote else { // Don't auto-sync when viewing a note
            return
        }
        
        await performFullSync(fetchAll: false)
    }
    
    @MainActor
    func syncIfNeeded() async {
        guard !isSyncing,
              networkManager.isConnected,
              isLoggedIn,
              !isViewingNote else { // Don't auto-sync when viewing a note
            return
        }
        
        let notesNeedingSync = coreDataManager.fetchNotesNeedingSync()
        
        if !notesNeedingSync.isEmpty {
            print("SyncManager: syncIfNeeded - \(notesNeedingSync.count) notes need syncing")
            await performFullSync(fetchAll: false)
        }
    }

    @MainActor
    func setAutoSyncEnabled(_ enabled: Bool) {
        guard isAutoSyncEnabled != enabled else { return }
        isAutoSyncEnabled = enabled
        
        if enabled {
            print("SyncManager: Auto-sync enabled")
            Task { [weak self] in
                await self?.syncIfNeeded()
            }
        } else {
            print("SyncManager: Auto-sync disabled")
        }
    }
    
    @MainActor
    func forceSync() async {
        guard networkManager.isConnected, isLoggedIn else {
            return
        }
        
        print("SyncManager: Force sync - fetching ALL notes from server")
        await performFullSync(fetchAll: true)
    }
    
    @MainActor
    func performInitialSync() async {
        await performFullSync(fetchAll: true)
    }
    
    @MainActor
    func performLoginSync() async {
        print("SyncManager: Starting login sync...")
        
        guard let user = coreDataManager.getCurrentUser(),
              let token = user.token else {
            print("SyncManager: No user or token for login sync")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // When login, fetch ALL notes from server first (don't use lastSyncTime)
            print("SyncManager: Fetching all notes from server on login...")
            
            let notesToSync = coreDataManager.fetchNotesNeedingSync()
            print("SyncManager: Local notes needing sync: \(notesToSync.count)")
            
            // Use nil for lastSyncTime to get ALL server notes
            let response = try await apiService.syncNotes(
                token: token,
                notes: notesToSync,
                lastSyncTime: nil  // Get all notes from server
            )
            
            print("SyncManager: Login sync received \(response.serverNotes.count) notes from server")
            
            await processSyncResponse(response, isFullFetch: true)
            await syncDeletedNotesIfNeeded(token: token, since: nil)
            
            print("SyncManager: Login sync completed successfully")
            let now = Date()
            lastSyncDate = now
            coreDataManager.updateLastSyncTime(now)
            
        } catch {
            print("SyncManager: Login sync failed: \(error)")
        }
    }
    
    @MainActor
    private func performFullSync(fetchAll: Bool = false) async {
        guard let user = coreDataManager.getCurrentUser(),
              let token = user.token else {
            return
        }
        
        await performSync(token: token, fetchAll: fetchAll)
    }

    @MainActor
    private func performSync(token: String, fetchAll: Bool = false) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Get all notes that need syncing (both regular and deleted)
            let notesToSync = coreDataManager.fetchNotesNeedingSync()
            
            print("SyncManager: Syncing \(notesToSync.count) local notes to server")
            
            // If fetchAll is true, ignore lastSyncDate to get ALL server notes
            let previousSyncTime = fetchAll ? nil : lastSyncDate
            
            if fetchAll {
                print("SyncManager: Fetching ALL notes from server (lastSyncTime = nil)")
            } else if let lastSync = previousSyncTime {
                print("SyncManager: Fetching notes updated after: \(lastSync)")
            } else {
                print("SyncManager: First sync - fetching all notes")
            }
            
            let response = try await apiService.syncNotes(
                token: token,
                notes: notesToSync,
                lastSyncTime: previousSyncTime
            )
            
            await processSyncResponse(response, isFullFetch: fetchAll || previousSyncTime == nil)
            await syncDeletedNotesIfNeeded(token: token, since: previousSyncTime)
            
            let now = Date()
            lastSyncDate = now
            coreDataManager.updateLastSyncTime(now)
            
            // Show success notification
            showSyncSuccessNotification(notesCount: response.serverNotes.count)
            
        } catch {
            print("SyncManager: Sync failed: \(error)")
            showSyncFailureNotification(error: error)
        }
    }
    
    private func processSyncResponse(_ response: SyncResponse, isFullFetch: Bool) async {
        print("SyncManager: Processing sync response with \(response.serverNotes.count) notes")
        
        await MainActor.run {
            coreDataManager.context.perform {
                do {
                    // Process server notes (including deleted ones)
                    for serverNote in response.serverNotes {
                        do {
                            self.processServerNote(serverNote)
                        } catch {
                            print("SyncManager: Error processing server note \(serverNote.id): \(error)")
                        }
                    }
                    
                    // Handle conflicts if any
                    for conflict in response.conflicts {
                        if let serverNote = conflict.serverNote {
                            do {
                                self.processServerNote(serverNote, isConflictResolution: true)
                            } catch {
                                print("SyncManager: Error processing conflict note: \(error)")
                            }
                        }
                    }
                    
                    if isFullFetch {
                        let serverIds = Set(response.serverNotes.map { $0.id.lowercased() })
                        self.pruneLocalNotesNotIn(serverIds: serverIds)
                    }
                    
                    // Save with error handling
                    do {
                        try self.coreDataManager.context.save()
                        print("SyncManager: Context saved successfully")
                    } catch {
                        print("SyncManager: Error saving context: \(error.localizedDescription)")
                        self.coreDataManager.context.rollback()
                    }
                    
                    // Debug: Print all notes after sync
                    print("SyncManager: === After Sync Debug ===")
                    self.coreDataManager.debugPrintAllData()
                } catch {
                    print("SyncManager: Fatal error in processSyncResponse: \(error.localizedDescription)")
                    self.coreDataManager.context.rollback()
                }
            }
        }
        
        // Notify UI to refresh with small delay to ensure Core Data is settled
        await MainActor.run {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("NotesUpdated"), object: nil)
            }
        }
        
        print("SyncManager: Sync response processed successfully")
    }
    
    private func pruneLocalNotesNotIn(serverIds: Set<String>) {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "tempDelete == NO AND serverId != nil")
        
        do {
            let localNotes = try coreDataManager.context.fetch(request)
            var removedCount = 0
            
            for note in localNotes {
                guard let serverId = note.serverId?.lowercased() else { continue }
                if !serverIds.contains(serverId) {
                    print("SyncManager: Removing stale local note missing on server: \(note.title ?? "Untitled")")
                    coreDataManager.context.delete(note)
                    removedCount += 1
                }
            }
            
            if removedCount > 0 {
                print("SyncManager: Removed \(removedCount) local notes not found on server during full sync")
            }
        } catch {
            print("SyncManager: Failed to prune local notes: \(error)")
        }
    }
    
    private func parseServerDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        return SyncManager.serverDateFormatter.date(from: string)
    }
    
    private func processServerNote(_ serverNote: APINote, isConflictResolution: Bool = false) {
        
        print("SyncManager: ========================================")
        print("SyncManager: Processing server note:")
        print("  - Server ID: \(serverNote.id)")
        print("  - Title: \(serverNote.title)")
        print("  - temp_delete: \(serverNote.temp_delete)")
        print("  - is_draft: \(serverNote.is_draft)")
        
        if let existingNote = findNote(by: serverNote.id) {
            // Update existing note
            print("SyncManager: Found existing note - updating")
            print("  - Existing local ID: \(existingNote.id ?? "nil")")
            print("  - Existing serverId: \(existingNote.serverId ?? "nil")")
            
            existingNote.title = serverNote.title.isEmpty ? "Không có tiêu đề" : serverNote.title
            existingNote.content = serverNote.content ?? ""
            existingNote.isDraft = serverNote.is_draft
            existingNote.tempDelete = serverNote.temp_delete == 1
            if let serverCreatedAt = parseServerDate(serverNote.created_at) {
                existingNote.createdAt = serverCreatedAt
            }
            let serverUpdatedAt = parseServerDate(serverNote.updated_at) ?? Date()
            existingNote.updatedAt = serverUpdatedAt
            existingNote.needsSync = false
            existingNote.syncedAt = parseServerDate(serverNote.synced_at) ?? serverUpdatedAt
            existingNote.serverId = serverNote.id.lowercased()
            
            print("  - Updated successfully - tempDelete: \(existingNote.tempDelete)")
        } else {
            print("SyncManager: No existing note found - creating new")
            
            // Double check for duplicates with lowercase serverId
            let duplicateCheck: NSFetchRequest<Note> = Note.fetchRequest()
            duplicateCheck.predicate = NSPredicate(format: "serverId == %@", serverNote.id.lowercased())
            
            do {
                let duplicates = try coreDataManager.context.fetch(duplicateCheck)
                print("  - Duplicate check found: \(duplicates.count) notes")
                
                if duplicates.isEmpty {
                    // Only create if no duplicate exists
                    print("  - Creating new note from server")
                    
                    // Validate required fields
                    guard !serverNote.id.isEmpty else {
                        print("  - ❌ Cannot create note: empty server ID")
                        return
                    }
                    
                    let note = Note(context: coreDataManager.context)
                    note.id = UUID().uuidString.lowercased()
                    note.serverId = serverNote.id.lowercased()
                    note.title = serverNote.title.isEmpty ? "Không có tiêu đề" : serverNote.title
                    note.content = serverNote.content ?? ""
                    note.isDraft = serverNote.is_draft
                    note.tempDelete = serverNote.temp_delete == 1
                    note.createdAt = parseServerDate(serverNote.created_at) ?? Date()
                    let serverUpdatedAt = parseServerDate(serverNote.updated_at) ?? Date()
                    note.updatedAt = serverUpdatedAt
                    note.needsSync = false
                    note.syncedAt = parseServerDate(serverNote.synced_at) ?? serverUpdatedAt
                    
                    print("  - ✅ Created note successfully:")
                    print("    - Local ID: \(note.id ?? "nil")")
                    print("    - Server ID: \(note.serverId ?? "nil")")
                    print("    - Title: \(note.title ?? "nil")")
                    print("    - Content length: \(note.content?.count ?? 0)")
                    print("    - tempDelete: \(note.tempDelete)")
                } else {
                    print("  - ⚠️ Duplicate note found with serverId: \(serverNote.id), skipping creation")
                    for dup in duplicates {
                        print("    - Duplicate: id=\(dup.id ?? "nil"), serverId=\(dup.serverId ?? "nil"), title=\(dup.title ?? "nil")")
                    }
                }
            } catch {
                print("  - ❌ Failed to check for duplicates: \(error)")
            }
        }
        print("SyncManager: ========================================")
    }
    
    private func syncDeletedNotesIfNeeded(token: String, since lastSyncTime: Date?) async {
        do {
            let deletedNotes = try await apiService.syncDeletedNotes(token: token, lastSyncTime: lastSyncTime)
            
            if deletedNotes.isEmpty {
                print("SyncManager: No server-side deletions to process")
                return
            }
            
            print("SyncManager: Processing \(deletedNotes.count) server-side deletions")
            
            await MainActor.run {
                coreDataManager.context.perform {
                    var removedCount = 0
                    
                    for deleted in deletedNotes {
                        if let localNote = self.findNote(by: deleted.id) {
                            print("SyncManager: Deleting local note removed on server: \(localNote.title ?? "Untitled")")
                            self.coreDataManager.context.delete(localNote)
                            removedCount += 1
                        } else {
                            print("SyncManager: Deleted note \(deleted.id) not found locally")
                        }
                    }
                    
                    if removedCount > 0 {
                        do {
                            try self.coreDataManager.context.save()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: NSNotification.Name("NotesUpdated"), object: nil)
                            }
                        } catch {
                            print("SyncManager: Error saving after deleting notes: \(error.localizedDescription)")
                            self.coreDataManager.context.rollback()
                        }
                    }
                }
            }
        } catch {
            print("SyncManager: Failed to sync deleted notes: \(error)")
        }
    }
    
    private func findNote(by id: String) -> Note? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let lowercaseId = id.lowercased()
        
        // Try to find by serverId first (most reliable)
        request.predicate = NSPredicate(format: "serverId == %@", lowercaseId)
        request.fetchLimit = 1
        
        do {
            let notes = try coreDataManager.context.fetch(request)
            if let found = notes.first {
                print("SyncManager: Found note by serverId: \(lowercaseId)")
                return found
            }
            
            // If not found by serverId, try by local id
            request.predicate = NSPredicate(format: "id == %@", lowercaseId)
            let notesByLocalId = try coreDataManager.context.fetch(request)
            if let found = notesByLocalId.first {
                print("SyncManager: Found note by local id: \(lowercaseId)")
                return found
            }
            
            print("SyncManager: Note not found with id: \(lowercaseId)")
            return nil
        } catch {
            print("SyncManager: Failed to find note: \(error)")
            return nil
        }
    }
    
    // MARK: - Manual Sync Triggers
    
    @MainActor
    func syncNote(_ note: Note) async {
        guard !notesCurrentlySyncing.contains(note.id ?? ""),
              networkManager.isConnected else {
            return
        }
        
        guard let user = coreDataManager.getCurrentUser(),
              let token = user.token else {
            return
        }
        
        // Add to currently syncing set
        notesCurrentlySyncing.insert(note.id ?? "")
        defer { notesCurrentlySyncing.remove(note.id ?? "") }
        
        do {
            // Check if this note was previously deleted (has serverId) and now being restored
            if let serverId = note.serverId, !serverId.isEmpty {
                if note.tempDelete {
                    // Temp delete: Call delete API to set temp_delete = 1 on server
                    print("SyncManager: Syncing temp delete for note: \(note.title ?? "Untitled")")
                    try await apiService.deleteNote(token: token, noteId: serverId)
                    print("SyncManager: Temp delete synced successfully")
                } else {
                    // Check if this is a restore operation (needsSync && !tempDelete && serverId exists)
                    // First check server state to see if it was deleted
                    print("SyncManager: Syncing update/restore for note: \(note.title ?? "Untitled")")
                    
                    // Try to restore first (in case it was deleted on server)
                    do {
                        try await apiService.restoreNote(token: token, noteId: serverId)
                        print("SyncManager: Note restored on server successfully")
                    } catch {
                        // If restore fails (note not in trash), just update it
                        print("SyncManager: Restore failed (note not in trash), updating instead")
                    }
                    
                    // Always update note content after restore
                    _ = try await apiService.updateNote(
                        token: token,
                        noteId: serverId,
                        title: note.title,
                        content: note.content,
                        isDraft: note.isDraft
                    )
                    print("SyncManager: Note updated on server")
                }
            } else if !note.tempDelete {
                // Create new note on server (only if not deleted)
                let createdNote = try await apiService.createNote(
                    token: token,
                    id: note.id,
                    title: note.title ?? "",
                    content: note.content ?? "",
                    isDraft: note.isDraft
                )
                
                // Update local note with server ID
                note.serverId = createdNote.id.lowercased()
            }
            
            note.needsSync = false
            note.syncedAt = Date()
            coreDataManager.save()
            
        } catch {
            print("SyncManager: Failed to sync note: \(error)")
        }
    }
    
    // MARK: - Individual Note Update Check
    
    func checkForUpdates(for note: Note, completion: @escaping (Note) -> Void) async {
        guard let serverId = note.serverId,
              let token = AuthManager.shared.getToken(),
              networkManager.isConnected else {
            return
        }
        
        do {
            let serverNote = try await apiService.getNote(token: token, noteId: serverId)
            
            // Compare server updated timestamp with local
            if let serverUpdatedAt = serverNote.updatedAt,
               let localUpdatedAt = note.updatedAt,
               serverUpdatedAt > localUpdatedAt {
                
                print("SyncManager: Server has newer version of note")
                
                // Update local note with server data
                await MainActor.run {
                    note.title = serverNote.title
                    note.content = serverNote.content
                    note.isDraft = serverNote.isDraft
                    note.updatedAt = serverUpdatedAt
                    note.syncedAt = serverNote.syncedAtDate ?? serverUpdatedAt
                    note.needsSync = false
                    
                    coreDataManager.save()
                    completion(note)
                }
            }
        } catch {
                        print("SyncManager: Failed to check for updates: \(error)")
        }
    }
    
    // MARK: - User Notifications
    
    @MainActor
    private func showSyncSuccessNotification(notesCount: Int) {
        #if canImport(UIKit)
        let message = notesCount > 0 
            ? "Đã đồng bộ \(notesCount) ghi chú thành công" 
            : "Đồng bộ thành công"
        
        // Post notification to NotificationCenter
        NotificationCenter.default.post(
            name: NSNotification.Name("SyncSuccess"),
            object: nil,
            userInfo: ["message": message, "count": notesCount]
        )
        
        // Show local notification banner
        showLocalNotification(title: "Đồng bộ thành công", message: message)
        #endif
    }
    
    @MainActor
    private func showSyncFailureNotification(error: Error) {
        #if canImport(UIKit)
        let message = "Lỗi đồng bộ: \(error.localizedDescription)"
        
        NotificationCenter.default.post(
            name: NSNotification.Name("SyncFailure"),
            object: nil,
            userInfo: ["message": message]
        )
        
        showLocalNotification(title: "Đồng bộ thất bại", message: message)
        #endif
    }
    
    @MainActor
    private func showLocalNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}
