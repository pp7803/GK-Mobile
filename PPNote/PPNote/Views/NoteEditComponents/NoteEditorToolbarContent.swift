import SwiftUI

struct NoteEditorToolbarContent: ToolbarContent {
    @Binding var showingFormatToolbar: Bool
    @Binding var isDraft: Bool
    @Binding var title: String
    let currentNote: Note?
    let onCancel: () -> Void
    let onSave: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                formatToolbarButton
                
                if isDraft || currentNote == nil {
                    draftToggleButton
                }
                
                saveButton
            }
        }
    }
    
    private var formatToolbarButton: some View {
        Button(action: { showingFormatToolbar.toggle() }) {
            Image(systemName: "textformat")
                .foregroundColor(showingFormatToolbar ? .blue : .gray)
        }
    }
    
    private var draftToggleButton: some View {
        Button(action: { isDraft.toggle() }) {
            Image(systemName: isDraft ? "doc.text.fill" : "doc.text")
                .foregroundColor(isDraft ? .orange : .blue)
        }
    }
    
    private var saveButton: some View {
        Button(action: onSave) {
            Text("Lưu")
                .fontWeight(.semibold)
        }
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
