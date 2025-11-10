import SwiftUI

struct TitleFieldView: View {
    @Binding var title: String
    let onChanged: () -> Void
    
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        TextField("Tiêu đề", text: $title)
            .font(.title2)
            .fontWeight(.bold)
            .padding(.horizontal)
            .padding(.top)
            .focused($isTitleFocused)
            .onChange(of: title) { _ in
                onChanged()
            }
            .onAppear {
                // Only auto-focus if title is empty (new note)
                if title.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isTitleFocused = true
                    }
                }
            }
    }
}
