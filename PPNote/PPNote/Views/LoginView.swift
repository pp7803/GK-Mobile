import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var isRegisterMode = false
    @State private var confirmPassword = ""
    @State private var showingForgotPassword = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: 60)
                    
                    // App Logo/Title Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "note.text")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("PPNote")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                            
                            Text(isRegisterMode ? "Tạo tài khoản mới" : "Chào mừng trở lại")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Form Section
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                TextField("Nhập email của bạn", text: $email)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .onChange(of: email) { _ in
                                        authManager.clearError()
                                    }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(email.isEmpty ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mật khẩu")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                SecureField("Nhập mật khẩu", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .onChange(of: password) { _ in
                                        authManager.clearError()
                                    }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(password.isEmpty ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Confirm Password (Register only)
                        if isRegisterMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Xác nhận mật khẩu")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.gray)
                                        .frame(width: 20)
                                    
                                    SecureField("Nhập lại mật khẩu", text: $confirmPassword)
                                        .textFieldStyle(PlainTextFieldStyle())
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(passwordsMatch ? Color.green.opacity(0.3) : (confirmPassword.isEmpty ? Color.clear : Color.red.opacity(0.3)), lineWidth: 1)
                                )
                                
                                if !confirmPassword.isEmpty && !passwordsMatch {
                                    Text("Mật khẩu không khớp")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .transition(.slide.combined(with: .opacity))
                        }
                        
                        // Password requirements (Register only)
                        if isRegisterMode && !password.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Yêu cầu mật khẩu:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(password.count >= 6 ? .green : .gray)
                                        .font(.caption)
                                    
                                    Text("Ít nhất 6 ký tự")
                                        .font(.caption)
                                        .foregroundColor(password.count >= 6 ? .green : .secondary)
                                }
                            }
                            .padding(.top, 4)
                            .transition(.slide.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Error Message
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .transition(.slide.combined(with: .opacity))
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Main Action Button
                        Button(action: handleSubmit) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: isRegisterMode ? "person.badge.plus" : "person.circle")
                                    Text(isRegisterMode ? "Tạo tài khoản" : "Đăng nhập")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isFormValid ? [Color.blue, Color.purple] : [Color.gray, Color.gray]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: isFormValid ? .blue.opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
                        }
                        .disabled(!isFormValid || authManager.isLoading)
                        .padding(.horizontal, 30)
                        
                        // Mode Toggle Button
                        Button(action: toggleMode) {
                            HStack(spacing: 4) {
                                Text(isRegisterMode ? "Đã có tài khoản?" : "Chưa có tài khoản?")
                                    .foregroundColor(.secondary)
                                
                                Text(isRegisterMode ? "Đăng nhập" : "Đăng ký")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            .font(.subheadline)
                        }
                        
                        // Forgot Password Button (Login mode only)
                        if !isRegisterMode {
                            Button(action: { showingForgotPassword = true }) {
                                Text("Quên mật khẩu?")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.top, 8)
                            }
                        }
                        
                        // Guest Mode Button
                        Button(action: dismissLogin) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.slash")
                                Text("Tiếp tục không đăng nhập")
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 10)
                        }
                    }
                    
                    Spacer(minLength: 30)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isRegisterMode)
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }
    
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@")
        let passwordValid = password.count >= 6
        
        if isRegisterMode {
            return emailValid && passwordValid && passwordsMatch
        } else {
            return emailValid && !password.isEmpty
        }
    }
    
    private var passwordsMatch: Bool {
        return password == confirmPassword
    }
    
    private func toggleMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isRegisterMode.toggle()
            // Clear confirm password when switching modes
            if !isRegisterMode {
                confirmPassword = ""
            }
            // Clear error message
            authManager.errorMessage = nil
        }
    }
    
    private func handleSubmit() {
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        Task {
            if isRegisterMode {
                await authManager.register(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            } else {
                await authManager.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            }
            
            // Dismiss if login/register successful
            if authManager.isLoggedIn {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func dismissLogin() {
        presentationMode.wrappedValue.dismiss()
    }
}