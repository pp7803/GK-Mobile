import SwiftUI

struct LeadingToolbarMenu: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var syncManager: SyncManager

    @Binding var showingDeletedNotes: Bool
    @Binding var showingLogin: Bool

    var body: some View {
        Menu {
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
}