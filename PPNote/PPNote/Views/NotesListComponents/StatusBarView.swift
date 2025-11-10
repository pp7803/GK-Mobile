import SwiftUI

struct StatusBarView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var syncManager: SyncManager
    @ObservedObject var authManager: AuthManager

    var body: some View {
        HStack {
            // Connection Status
            HStack(spacing: 4) {
                Circle()
                    .fill(networkManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(networkManager.isConnected ? "Đã kết nối" : "Không có mạng")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sync Status
            if syncManager.isSyncing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Đang đồng bộ...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let lastSync = syncManager.lastSyncDate {
                Text("Đồng bộ: \(formatDate(lastSync))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // User Status
            if authManager.isLoggedIn {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                    Text(authManager.currentUser?.email ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .foregroundColor(.gray)
                    Text("Chế độ khách")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}