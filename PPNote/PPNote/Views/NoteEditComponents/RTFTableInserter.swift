import SwiftUI

// MARK: - RTF Table Inserter
struct RTFTableInserter: View {
    let onTableCreated: (String) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var rows = 3
    @State private var columns = 3

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("Số hàng: \(rows)")
                    Slider(value: Binding(
                        get: { Double(rows) },
                        set: { rows = Int($0) }
                    ), in: 1...10, step: 1)
                    
                    Text("Số cột: \(columns)")
                    Slider(value: Binding(
                        get: { Double(columns) },
                        set: { columns = Int($0) }
                    ), in: 1...10, step: 1)
                }
                .padding(.horizontal)
                
                Button(action: {
                    let tableHTML = createTableHTML(rows: rows, columns: columns)
                    onTableCreated(tableHTML)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Tạo bảng")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("Chèn bảng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Hủy") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func createTableHTML(rows: Int, columns: Int) -> String {
        var html = "<table border=\"1\" style=\"border-collapse: collapse; width: 100%;\">"

        for row in 0..<rows {
            html += "<tr>"
            for col in 0..<columns {
                html += "<td style=\"padding: 8px;\">Nội dung</td>"
            }
            html += "</tr>"
        }

        html += "</table>"
        return html
    }
}