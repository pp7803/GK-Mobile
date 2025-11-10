import SwiftUI

struct RTFFormatToolbar: View {
    // Use regular properties instead of @Binding to prevent re-render loops
    let isBold: Bool
    let isItalic: Bool
    let isUnderline: Bool
    let fontSize: CGFloat
    let textColor: Color

    let onImageInsert: () -> Void
    let onAIImageInsert: () -> Void
    let onTableInsert: () -> Void
    let onListInsert: () -> Void
    let onQuoteInsert: () -> Void
    let onDividerInsert: () -> Void
    let onDateInsert: () -> Void
    let onTimeInsert: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onBoldToggle: () -> Void
    let onItalicToggle: () -> Void
    let onUnderlineToggle: () -> Void
    let onFontSizeChange: (CGFloat) -> Void
    let onTextColorChange: (Color) -> Void
    
    @State private var localTextColor: Color = .primary

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Group {
                    FormatButton(
                        icon: "arrow.uturn.backward",
                        isActive: false,
                        action: onUndo
                    )
                    
                    FormatButton(
                        icon: "arrow.uturn.forward",
                        isActive: false,
                        action: onRedo
                    )
                }
                
                Divider()
                    .frame(height: 20)
                
                // Text formatting
                Group {
                    FormatButton(
                        icon: "bold",
                        isActive: isBold,
                        action: onBoldToggle
                    )

                    FormatButton(
                        icon: "italic",
                        isActive: isItalic,
                        action: onItalicToggle
                    )

                    FormatButton(
                        icon: "underline",
                        isActive: isUnderline,
                        action: onUnderlineToggle
                    )
                }

                Divider()
                    .frame(height: 20)

                // Font size - Extended range
                HStack(spacing: 4) {
                    Button {
                        let newSize = max(8, fontSize - 1) // Minimum size 8, decrease by 1
                        onFontSizeChange(newSize)
                    } label: {
                        Image(systemName: "minus")
                            .foregroundColor(.primary)
                            .padding(6)
                    }
                    .buttonStyle(.borderless)
                    .disabled(fontSize <= 8)

                    Text("\(Int(fontSize))")
                        .frame(minWidth: 35)
                        .foregroundColor(.primary)
                        .font(.system(size: 12, weight: .medium))
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.1))
                        )

                    Button {
                        let newSize = min(48, fontSize + 1) // Maximum size 48, increase by 1
                        onFontSizeChange(newSize)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.primary)
                            .padding(6)
                    }
                    .buttonStyle(.borderless)
                    .disabled(fontSize >= 48)
                }
                
                Divider()
                    .frame(height: 20)
                
                // Text color
                ColorPicker("", selection: $localTextColor)
                    .labelsHidden()
                    .frame(width: 30)
                    .onChange(of: localTextColor) { newColor in
                        onTextColorChange(newColor)
                    }
                    .onAppear {
                        if localTextColor != textColor {
                            localTextColor = textColor
                        }
                    }
                    .onChange(of: textColor) { newValue in
                        if localTextColor != newValue {
                            localTextColor = newValue
                        }
                    }

                Divider()
                    .frame(height: 20)

                // Content insertion - simplified
                Group {
                    FormatButton(
                        icon: "wand.and.stars",
                        isActive: false,
                        action: onAIImageInsert
                    )
                    
                    FormatButton(
                        icon: "photo",
                        isActive: false,
                        action: onImageInsert
                    )
                    
                    FormatButton(
                        icon: "table",
                        isActive: false,
                        action: onTableInsert
                    )
                    
                    FormatButton(
                        icon: "list.bullet",
                        isActive: false,
                        action: onListInsert
                    )
                    
                    FormatButton(
                        icon: "calendar",
                        isActive: false,
                        action: onDateInsert
                    )
                    
                    FormatButton(
                        icon: "clock", 
                        isActive: false,
                        action: onTimeInsert
                    )
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
        .background(Color(.systemGray6))
    }
}

struct FormatButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .foregroundColor(isActive ? .white : .primary)
                .padding(8)
                .background(isActive ? Color.blue : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.borderless)
    }
}
