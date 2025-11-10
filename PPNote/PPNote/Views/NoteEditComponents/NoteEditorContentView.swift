import SwiftUI
import PhotosUI
import WebKit

struct NoteEditorContentView: View {
    @Binding var calculationResult: String?
    @Binding var showingFormatToolbar: Bool
    @Binding var content: String
    // Changed from @Binding to regular properties - read-only states
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var fontSize: CGFloat
    var textColor: Color
    var selectedRange: NSRange
    @FocusState.Binding var isContentFocused: Bool
    
    let onContentChange: (String) -> Void
    let onListInsert: () -> Void
    let onQuoteInsert: () -> Void
    let onDividerInsert: () -> Void
    let onDateInsert: () -> Void
    let onTimeInsert: () -> Void
    let onImagePickerShow: () -> Void
    let onAIImageGeneratorShow: () -> Void
    let onTableInserterShow: () -> Void
    let onCalculationAdd: () -> Void
    let onCalculationDismiss: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onBoldToggle: () -> Void
    let onItalicToggle: () -> Void
    let onUnderlineToggle: () -> Void
    let onFontSizeChange: (CGFloat) -> Void
    let onFontSizeDetected: (CGFloat) -> Void
    let onTextColorChange: (Color) -> Void
    let onWebViewReady: (WKWebView) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Calculation hint
            if let result = calculationResult {
                calculationResultView(result: result)
            }
            
            // Format toolbar
            if showingFormatToolbar {
                RTFFormatToolbar(
                    isBold: isBold,
                    isItalic: isItalic,
                    isUnderline: isUnderline,
                    fontSize: fontSize,
                    textColor: textColor,
                    onImageInsert: onImagePickerShow,
                    onAIImageInsert: onAIImageGeneratorShow,
                    onTableInsert: onTableInserterShow,
                    onListInsert: onListInsert,
                    onQuoteInsert: onQuoteInsert,
                    onDividerInsert: onDividerInsert,
                    onDateInsert: onDateInsert,
                    onTimeInsert: onTimeInsert,
                    onUndo: onUndo,
                    onRedo: onRedo,
                    onBoldToggle: onBoldToggle,
                    onItalicToggle: onItalicToggle,
                    onUnderlineToggle: onUnderlineToggle,
                    onFontSizeChange: onFontSizeChange,
                    onTextColorChange: onTextColorChange
                )
                .padding(.horizontal)
            }
            
            // UtilityToolbar removed - all functions now in RTFFormatToolbar
            
            // Rich Text Editor
            RichTextEditor(
                htmlContent: $content,
                isBold: isBold,
                isItalic: isItalic,
                isUnderline: isUnderline,
                fontSize: fontSize,
                textColor: textColor,
                selectedRange: selectedRange,
                onContentChange: onContentChange,
                onTableInsert: onTableInserterShow,
                onListInsert: onListInsert,
                onQuoteInsert: onQuoteInsert,
                onDividerInsert: onDividerInsert,
                onBoldToggle: onBoldToggle,
                onItalicToggle: onItalicToggle,
                onUnderlineToggle: onUnderlineToggle,
                onFontSizeChange: onFontSizeChange,
                onFontSizeDetected: onFontSizeDetected,
                onWebViewReady: onWebViewReady
            )
            .frame(minHeight: 300)
            .focused($isContentFocused)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func calculationResultView(result: String) -> some View {
        HStack {
            Image(systemName: "equal.circle.fill")
                .foregroundColor(.green)
            Text("Kết quả: \(result)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)
            
            Spacer()
            
            Button(action: onCalculationAdd) {
                Text("Thêm")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Button(action: onCalculationDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .transition(.slide.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: calculationResult)
    }

}
