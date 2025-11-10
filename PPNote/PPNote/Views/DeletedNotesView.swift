import SwiftUI
import CoreData

struct DeletedNotesView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)],
        predicate: NSPredicate(format: "tempDelete == YES"),
        animation: .default)
    private var deletedNotes: FetchedResults<Note>
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDeleteAllConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(deletedNotes, id: \.id) { deletedNote in
                    DeletedNoteRowView(deletedNote: deletedNote)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Đã xóa gần đây")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xóa tất cả") {
                        showingDeleteAllConfirmation = true
                    }
                    .disabled(deletedNotes.isEmpty)
                }
            }
            .onAppear {
                // Auto cleanup old deleted notes (older than 30 days)
                coreDataManager.cleanupOldDeletedNotes()
            }
        }
        .alert("Lỗi", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Xóa vĩnh viễn tất cả ghi chú", isPresented: $showingDeleteAllConfirmation) {
            Button("Xóa vĩnh viễn", role: .destructive) {
                deleteAllPermanently()
            }
            Button("Hủy", role: .cancel) { }
        } message: {
            let isLoggedIn = authManager.isLoggedIn
            if isLoggedIn {
                Text("Tất cả \(deletedNotes.count) ghi chú trong thùng rác sẽ bị xóa vĩnh viễn khỏi thiết bị VÀ máy chủ (bao gồm file RTF) và không thể khôi phục.")
            } else {
                Text("Tất cả \(deletedNotes.count) ghi chú trong thùng rác sẽ bị xóa vĩnh viễn khỏi thiết bị.\n\nLưu ý: Khi đăng nhập, các ghi chú này vẫn còn trên máy chủ.")
            }
        }
    }
    
    private func deleteAllPermanently() {
        Task {
            for deletedNote in deletedNotes {
                do {
                    try await coreDataManager.permanentlyDeleteNote(deletedNote)
                } catch {
                    await MainActor.run {
                        alertMessage = "Lỗi xóa ghi chú: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        }
    }
}

struct DeletedNoteRowView: View {
    let deletedNote: Note
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var showingDeleteConfirmation = false
    @State private var showingRestoreConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Note info section
            VStack(alignment: .leading, spacing: 4) {
                Text(deletedNote.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(2)
                
                if let content = deletedNote.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if let deletedDate = deletedNote.updatedAt {
                        Text("Đã xóa \(formatDate(deletedDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    let daysLeft = daysUntilPermanentDeletion(from: deletedNote.updatedAt ?? Date())
                    if daysLeft > 0 {
                        Text("\(daysLeft) ngày còn lại")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    } else {
                        Text("Sẽ xóa vĩnh viễn")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
            }
            
            // Action buttons section
            HStack(spacing: 12) {
                // Restore button
                Button(action: { showingRestoreConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Khôi phục")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
                
                // Delete permanently button
                Button(action: { showingDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Xóa vĩnh viễn")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 8)
        .confirmationDialog("Khôi phục ghi chú", isPresented: $showingRestoreConfirmation) {
            Button("Khôi phục", role: .none) {
                restoreNote()
            }
            Button("Hủy", role: .cancel) { }
        } message: {
            let isLoggedIn = authManager.isLoggedIn
            if isLoggedIn {
                Text("Ghi chú \"\(deletedNote.title ?? "Untitled")\" sẽ được khôi phục về danh sách ghi chú trên thiết bị và máy chủ.")
            } else {
                Text("Ghi chú \"\(deletedNote.title ?? "Untitled")\" sẽ được khôi phục về danh sách ghi chú trên thiết bị.")
            }
        }
        .confirmationDialog("Xóa vĩnh viễn ghi chú", isPresented: $showingDeleteConfirmation) {
            Button("Xóa vĩnh viễn", role: .destructive) {
                deletePermanently()
            }
            Button("Hủy", role: .cancel) { }
        } message: {
            let isLoggedIn = authManager.isLoggedIn
            if isLoggedIn {
                Text("Ghi chú \"\(deletedNote.title ?? "Untitled")\" sẽ bị xóa vĩnh viễn khỏi thiết bị VÀ máy chủ (bao gồm file RTF) và không thể khôi phục.")
            } else {
                Text("Ghi chú \"\(deletedNote.title ?? "Untitled")\" sẽ bị xóa vĩnh viễn khỏi thiết bị và không thể khôi phục.\n\nLưu ý: Khi đăng nhập, ghi chú này vẫn còn trên máy chủ.")
            }
        }
    }
    
    private func restoreNote() {
        coreDataManager.restoreNote(deletedNote)
    }
    
    private func deletePermanently() {
        Task {
            do {
                try await coreDataManager.permanentlyDeleteNote(deletedNote)
            } catch {
                // Handle error
                print("Error permanently deleting note: \(error)")
            }
        }
    }
    
    private func daysUntilPermanentDeletion(from deletedDate: Date) -> Int {
        let calendar = Calendar.current
        let thirtyDaysLater = calendar.date(byAdding: .day, value: 30, to: deletedDate) ?? deletedDate
        let today = Date()
        
        if thirtyDaysLater > today {
            return calendar.dateComponents([.day], from: today, to: thirtyDaysLater).day ?? 0
        } else {
            return 0
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    DeletedNotesView()
}