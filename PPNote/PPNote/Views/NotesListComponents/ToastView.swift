import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String
    let backgroundColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String
    let backgroundColor: Color
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    ToastView(message: message, icon: icon, backgroundColor: backgroundColor)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: isShowing)
                    
                    Spacer()
                }
                .zIndex(1)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(
        isShowing: Binding<Bool>,
        message: String,
        icon: String = "checkmark.circle.fill",
        backgroundColor: Color = .green,
        duration: TimeInterval = 3.0
    ) -> some View {
        modifier(ToastModifier(
            isShowing: isShowing,
            message: message,
            icon: icon,
            backgroundColor: backgroundColor,
            duration: duration
        ))
    }
}

#Preview {
    VStack {
        Text("Main Content")
    }
    .toast(
        isShowing: .constant(true),
        message: "Đã đồng bộ 5 ghi chú thành công",
        icon: "checkmark.circle.fill",
        backgroundColor: .green
    )
}
