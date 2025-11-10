import SwiftUI

struct CalculationResultView: View {
    let result: String
    let onAddResult: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "equal.circle.fill")
                .foregroundColor(.green)
            Text("Kết quả: \(result)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)

            Spacer()

            Button(action: onAddResult) {
                Text("Thêm")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.borderless)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}