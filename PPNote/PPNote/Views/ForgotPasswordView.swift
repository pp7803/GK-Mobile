//
//  ForgotPasswordView.swift
//  PPNote
//
//  Created by Phát Phạm on 22/10/25.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    
    @State private var email = ""
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var currentStep: ResetStep = .enterEmail
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Thông báo"
    
    @State private var resetToken = ""
    @State private var remainingTime = 0
    @State private var timer: Timer?
    
    enum ResetStep {
        case enterEmail
        case enterOTP
        case enterNewPassword
        case success
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient như LoginView
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer(minLength: 40)
                        
                        // Header
                        headerView
                        
                        // Content based on current step
                        VStack(spacing: 24) {
                            switch currentStep {
                            case .enterEmail:
                                emailStepView
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            case .enterOTP:
                                otpStepView
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            case .enterNewPassword:
                                newPasswordStepView
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            case .success:
                                successStepView
                                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            }
                        }
                        .padding(.horizontal, 30)
                        .animation(.easeInOut(duration: 0.5), value: currentStep)
                        
                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("Quên mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                    .foregroundColor(Color.blue)
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            timer?.invalidate()
        }
        // Custom alert overlay cho success messages
        .overlay(
            Group {
                if showingAlert && alertTitle == "Thành công" {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.green)
                            Text(alertMessage)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .padding()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showingAlert = false
                        }
                    }
                }
            }
        )
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Icon với gradient như LoginView
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: currentStep == .success ? [Color.green, Color.green.opacity(0.7)] : [Color.blue, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                    .shadow(color: (currentStep == .success ? Color.green : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: currentStep == .success ? "checkmark.circle.fill" : "key.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                Text(stepTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(LinearGradient(
                        gradient: Gradient(colors: currentStep == .success ? [Color.green, Color.green.opacity(0.7)] : [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .multilineTextAlignment(.center)
                
                Text(stepDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
    }
    
    private var emailStepView: some View {
        VStack(spacing: 20) {
            // Email Field với style như LoginView
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(Color.gray)
                        .frame(width: 20)
                    
                    TextField("Nhập email của bạn", text: $email)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(email.isEmpty ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Send OTP Button với gradient
            Button(action: requestOTP) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("Gửi mã OTP")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: (email.isEmpty || isLoading) ? [Color.gray, Color.gray] : [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: (email.isEmpty || isLoading) ? Color.clear : Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .disabled(email.isEmpty || isLoading)
        }
    }
    
    private var otpStepView: some View {
        VStack(spacing: 20) {
            // OTP Field với style như LoginView
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mã OTP")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if remainingTime > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(formatTime(remainingTime))")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    TextField("Nhập mã OTP 6 số", text: $otpCode)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .onChange(of: otpCode) { newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                otpCode = String(newValue.prefix(6))
                            }
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(otpCode.isEmpty ? Color.clear : (otpCode.count == 6 ? Color.green.opacity(0.3) : Color.blue.opacity(0.3)), lineWidth: 1)
                )
                
                Text("Mã OTP đã được gửi đến: \(email)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Verify Button
            Button(action: verifyOTP) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.shield")
                        Text("Xác thực OTP")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: (otpCode.count != 6 || isLoading) ? [Color.gray, Color.gray] : [Color.green, Color.green.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: (otpCode.count != 6 || isLoading) ? Color.clear : Color.green.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .disabled(otpCode.count != 6 || isLoading)
            
            // Resend Button
            Button(action: requestOTP) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Gửi lại mã OTP")
                }
                .font(.subheadline)
                .foregroundColor(remainingTime > 0 || isLoading ? Color.gray : Color.blue)
            }
            .disabled(remainingTime > 0 || isLoading)
        }
    }
    
    private var newPasswordStepView: some View {
        VStack(spacing: 20) {
            // New Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Mật khẩu mới")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    SecureField("Nhập mật khẩu mới", text: $newPassword)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(newPassword.isEmpty ? Color.clear : (newPassword.count >= 6 ? Color.green.opacity(0.3) : Color.orange.opacity(0.3)), lineWidth: 1)
                )
                
                Text("Tối thiểu 6 ký tự")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Xác nhận mật khẩu")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    SecureField("Nhập lại mật khẩu mới", text: $confirmPassword)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(confirmPassword.isEmpty ? Color.clear : (newPassword == confirmPassword ? Color.green.opacity(0.3) : Color.red.opacity(0.3)), lineWidth: 1)
                )
                
                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Text("Mật khẩu không khớp")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Password requirements
            if !newPassword.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yêu cầu mật khẩu:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: newPassword.count >= 6 ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(newPassword.count >= 6 ? Color.green : Color.gray)
                            .font(.caption)
                        
                        Text("Ít nhất 6 ký tự")
                            .font(.caption)
                            .foregroundColor(newPassword.count >= 6 ? Color.green : .secondary)
                    }
                }
                .padding(.top, 4)
            }
            
            // Reset Password Button
            Button(action: resetPassword) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "key.fill")
                        Text("Đặt lại mật khẩu")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: (!isPasswordValid || isLoading) ? [Color.gray, Color.gray] : [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: (!isPasswordValid || isLoading) ? Color.clear : Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .disabled(!isPasswordValid || isLoading)
        }
    }
    
    private var successStepView: some View {
        VStack(spacing: 24) {
            // Success Animation
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 60))
                
                Text("Thành công!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            }
            
            Text("Mật khẩu của bạn đã được đặt lại thành công.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            // Success Actions
            VStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("Đăng nhập ngay")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                
                Button(action: { dismiss() }) {
                    Text("Về trang chủ")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case .enterEmail:
            return "Nhập email của bạn"
        case .enterOTP:
            return "Nhập mã xác thực"
        case .enterNewPassword:
            return "Tạo mật khẩu mới"
        case .success:
            return "Đặt lại mật khẩu thành công"
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case .enterEmail:
            return "Chúng tôi sẽ gửi mã OTP đến email để xác thực danh tính của bạn"
        case .enterOTP:
            return "Kiểm tra email và nhập mã OTP 6 số đã được gửi"
        case .enterNewPassword:
            return "Tạo mật khẩu mới an toàn cho tài khoản của bạn"
        case .success:
            return "Bạn có thể đăng nhập với mật khẩu mới"
        }
    }
    
    private var isPasswordValid: Bool {
        return newPassword.count >= 6 && newPassword == confirmPassword
    }
    
    private func requestOTP() {
        guard !email.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let result = await authManager.requestPasswordReset(email: email)
                
                await MainActor.run {
                    isLoading = false
                    
                    if result.success {
                        currentStep = .enterOTP
                        startCountdown()
                        alertTitle = "Thành công"
                        alertMessage = result.message
                        showingAlert = true
                    } else {
                        alertTitle = "Lỗi"
                        alertMessage = result.message
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private func verifyOTP() {
        guard otpCode.count == 6 else { return }
        
        isLoading = true
        
        Task {
            do {
                let result = await authManager.verifyOTP(email: email, otp: otpCode)
                
                await MainActor.run {
                    isLoading = false
                    
                    if result.success, let token = result.resetToken {
                        resetToken = token
                        currentStep = .enterNewPassword
                        timer?.invalidate() // Stop countdown
                    } else {
                        alertTitle = "Lỗi"
                        alertMessage = result.message
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private func resetPassword() {
        guard isPasswordValid else { return }
        
        isLoading = true
        
        Task {
            do {
                let result = await authManager.resetPassword(token: resetToken, newPassword: newPassword)
                
                await MainActor.run {
                    isLoading = false
                    
                    if result.success {
                        currentStep = .success
                    } else {
                        alertTitle = "Lỗi"
                        alertMessage = result.message
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private func startCountdown() {
        remainingTime = 600 // 10 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ForgotPasswordView()
}