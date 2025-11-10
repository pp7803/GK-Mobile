import SwiftUI
import CoreData

struct NoteCardView: View {
    let note: Note
    let useServerTimestamps: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and tags
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title ?? "Ghi chú không có tiêu đề")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(sourceLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if note.isDraft {
                            Text("• Nháp")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        if note.needsSync {
                            Text("• Chờ đồng bộ")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                // Status indicators
                VStack(spacing: 4) {
                    if note.isDraft {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                    }

                    if note.needsSync {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }
            }

            // Content preview
            if let content = note.content, !content.isEmpty {
                Text(NoteFormattingHelper.stripHTMLTags(from: content))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Không có nội dung")
                    .font(.body)
                    .foregroundColor(Color(.systemGray3))
                    .italic()
            }

            timestampSection

            // Bottom row with additional info
            HStack {
                if let content = note.content {
                    let plainText = NoteFormattingHelper.stripHTMLTags(from: content)
                    Text("\(plainText.count) ký tự")
                        .font(.caption2)
                        .foregroundColor(Color(.systemGray3))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }

    private var timestampSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let createdAt = createdDate {
                Text("Tạo: \(formatDate(createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let updatedAt = updatedDate {
                Text("Chỉnh sửa mới nhất: \(formatDate(updatedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if useServerTimestamps, let syncedAt = note.syncedAt {
                Text("Đồng bộ: \(formatDate(syncedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var createdDate: Date? {
        note.createdAt
    }

    private var updatedDate: Date? {
        note.updatedAt
    }
    
    private var sourceLabel: String {
        useServerTimestamps ? "Đồng bộ máy chủ" : "Dữ liệu cục bộ"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if useServerTimestamps {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.timeZone = .autoupdatingCurrent
        }
        return formatter.string(from: date)
    }
}
