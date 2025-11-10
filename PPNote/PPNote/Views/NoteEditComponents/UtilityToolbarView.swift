import SwiftUI

struct UtilityToolbarView: View {
    let onListInsert: () -> Void
    let onDateInsert: () -> Void
    let onTimeInsert: () -> Void
    let onTableInsert: () -> Void
    let onImageInsert: () -> Void
    
    var body: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Only show icons without titles - remove date/time icons
                    Button(action: onDateInsert) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onTimeInsert) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}
