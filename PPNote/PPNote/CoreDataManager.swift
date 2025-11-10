import Foundation
import CoreData
import Combine

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "PPNoteDataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data context: \(error)")
            }
        }
    }
    
    // MARK: - Note Operations
    
    func createNote(title: String? = nil, content: String, isDraft: Bool = false) -> Note {
        let note = Note(context: context)
        note.id = UUID().uuidString.lowercased()
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            note.title = title
        } else {
            note.title = nil
        }
        note.content = content
        note.isDraft = isDraft
        note.tempDelete = false
        note.createdAt = Date()
        note.updatedAt = Date()
        note.needsSync = true
        
        save()
        return note
    }
    
    func updateNote(
        _ note: Note,
        title: String? = nil,
        content: String? = nil,
        isDraft: Bool? = nil,
        allowEmptyTitle: Bool = false
    ) {
        if Thread.isMainThread {
            performUpdate(
                note: note,
                title: title,
                content: content,
                isDraft: isDraft,
                allowEmptyTitle: allowEmptyTitle
            )
        } else {
            DispatchQueue.main.sync {
                performUpdate(
                    note: note,
                    title: title,
                    content: content,
                    isDraft: isDraft,
                    allowEmptyTitle: allowEmptyTitle
                )
            }
        }
    }
    
    private func performUpdate(
        note: Note,
        title: String?,
        content: String?,
        isDraft: Bool?,
        allowEmptyTitle: Bool
    ) {
        var hasChanges = false
        
        if let title = title {
            let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedTitle.isEmpty {
                if allowEmptyTitle && note.title != nil {
                    note.title = nil
                    hasChanges = true
                }
            } else if note.title != normalizedTitle {
                note.title = normalizedTitle
                hasChanges = true
            }
        }
        if let content = content, note.content != content {
            note.content = content
            hasChanges = true
        }
        if let isDraft = isDraft, note.isDraft != isDraft {
            note.isDraft = isDraft
            hasChanges = true
        }
        
        if hasChanges {
            note.updatedAt = Date()
            note.needsSync = true
            
            do {
                try context.save()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("NotesUpdated"), object: nil)
                }
            } catch {
                print("CoreDataManager: Failed to save note update: \(error)")
            }
        }
    }
    
    func deleteNote(_ note: Note) {
        print("CoreDataManager: Deleting note (temp_delete): \(note.title ?? "Untitled")")
        
        note.tempDelete = true
        note.needsSync = true
        note.updatedAt = Date()
        
        save()
        
        print("CoreDataManager: Note marked as temp_delete=true, needsSync=true")
        
        if let user = getCurrentUser(), user.isLoggedIn {
            print("CoreDataManager: User is logged in, syncing temp delete to server...")
            Task {
                await SyncManager.shared.syncNote(note)
            }
        } else {
            print("CoreDataManager: User not logged in, temp delete will sync on next login")
        }
    }
    
    func fetchNotes() -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "tempDelete == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch notes: \(error)")
            return []
        }
    }
    
    func fetchDeletedNotes() -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "tempDelete == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch deleted notes: \(error)")
            return []
        }
    }
    
    func fetchNotesNeedingSync() -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch notes needing sync: \(error)")
            return []
        }
    }
    
    func restoreNote(_ note: Note) {
        print("CoreDataManager: Restoring note: \(note.title ?? "Untitled")")
        
        note.tempDelete = false
        note.needsSync = true
        note.updatedAt = Date()
        save()
        
        print("CoreDataManager: Note restored locally - tempDelete: false, needsSync: true")
        
        if let user = getCurrentUser(), user.isLoggedIn {
            print("CoreDataManager: User is logged in, syncing restore to server...")
            Task {
                await SyncManager.shared.syncNote(note)
            }
        } else {
            print("CoreDataManager: User not logged in, will sync on next login")
        }
    }
    
    func permanentlyDeleteNote(_ note: Note) async throws {
        let noteTitle = note.title ?? "Untitled"
        let noteId = note.serverId ?? note.id ?? "unknown"
        
        print("CoreDataManager: Permanently deleting note: \(noteTitle)")
        
        // If logged in and note has serverId, delete from server first
        if let user = getCurrentUser(), user.isLoggedIn, let serverId = note.serverId, !serverId.isEmpty {
            do {
                print("CoreDataManager: User is logged in, deleting from server...")
                try await APIService.shared.permanentlyDeleteNote(token: user.token!, noteId: serverId)
                print("CoreDataManager: Successfully deleted from server")
            } catch {
                print("CoreDataManager: Failed to delete from server: \(error)")
                throw error
            }
        } else {
            print("CoreDataManager: User not logged in or no serverId, only deleting locally")
        }
        
        // Delete locally
        print("CoreDataManager: Deleting note locally from Core Data")
        context.delete(note)
        save()
        
        print("CoreDataManager: Note permanently deleted: \(noteTitle)")
    }
    
    func cleanupOldDeletedNotes() {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "tempDelete == YES AND updatedAt < %@", thirtyDaysAgo as NSDate)
        
        do {
            let oldDeletedNotes = try context.fetch(request)
            for note in oldDeletedNotes {
                Task {
                    try? await permanentlyDeleteNote(note)
                }
            }
        } catch {
            print("Failed to cleanup old deleted notes: \(error)")
        }
    }
    
    // MARK: - User Operations
    
    func getCurrentUser() -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "isLoggedIn == true")
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch current user: \(error)")
            return nil
        }
    }
    
    func createOrUpdateUser(id: Int32, email: String, token: String) {
        // Clear existing users
        let request: NSFetchRequest<User> = User.fetchRequest()
        do {
            let existingUsers = try context.fetch(request)
            for user in existingUsers {
                context.delete(user)
            }
        } catch {
            print("Failed to clear existing users: \(error)")
        }
        
        // Create new user
        let user = User(context: context)
        user.id = id
        user.email = email
        user.token = token
        user.isLoggedIn = true
        user.lastSyncTime = nil
        
        save()
    }
    
    func logoutUser() {
        let request: NSFetchRequest<User> = User.fetchRequest()
        do {
            let users = try context.fetch(request)
            for user in users {
                context.delete(user)
            }
            save()
        } catch {
            print("Failed to logout user: \(error)")
        }
    }
    
    func updateLastSyncTime(_ date: Date) {
        if let user = getCurrentUser() {
            user.lastSyncTime = date
            save()
        }
    }
    
    // MARK: - Debug Functions
    
    func debugPrintAllData() {
        let allNotesRequest: NSFetchRequest<Note> = Note.fetchRequest()
        allNotesRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
        do {
            let allNotes = try context.fetch(allNotesRequest)
            print("=== ALL NOTES: \(allNotes.count) ===")
            
            for note in allNotes {
                print("  - id: \(note.id ?? "nil"), serverId: \(note.serverId ?? "nil"), title: \(note.title ?? "Untitled"), tempDelete: \(note.tempDelete), needsSync: \(note.needsSync)")
            }
            
            let activeNotes = allNotes.filter { !$0.tempDelete }
            print("=== ACTIVE NOTES (tempDelete=false): \(activeNotes.count) ===")
            for note in activeNotes {
                print("  - title: \(note.title ?? "Untitled"), id: \(note.id ?? "nil")")
            }
            
            let deletedNotes = allNotes.filter { $0.tempDelete }
            print("=== DELETED NOTES (tempDelete=true): \(deletedNotes.count) ===")
            
            for note in deletedNotes {
                print("  - id: \(note.id ?? "nil"), title: \(note.title ?? "Untitled")")
            }
            
        } catch {
            print("Failed to fetch notes for debug: \(error)")
        }
        
        if let user = getCurrentUser() {
            print("=== User: \(user.email ?? "nil") ===")
        }
    }
}
