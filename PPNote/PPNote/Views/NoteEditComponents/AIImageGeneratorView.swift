import SwiftUI
import UIKit

struct AIImageGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var aiService = AIService.shared
    
    @State private var prompt: String = ""
    @State private var generatedResult: GeneratedImageResult?
    @State private var errorMessage: String?
    @State private var isInserting = false
    @FocusState private var isPromptFocused: Bool
    
    let onInsert: (Data, String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Mô tả hình ảnh") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                        .focused($isPromptFocused)
                        .disabled(aiService.isGeneratingImage)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Kết quả") {
                    if aiService.isGeneratingImage {
                        HStack {
                            ProgressView()
                            Text("Đang tạo hình ảnh...")
                                .foregroundColor(.secondary)
                        }
                    } else if let result = generatedResult,
                              let uiImage = UIImage(data: result.data) {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            
                            if let description = result.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Nhập mô tả và nhấn \"Tạo ảnh\" để bắt đầu.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded { isPromptFocused = false })
            .navigationTitle("Tạo ảnh với AI")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Tạo ảnh") {
                        Task {
                            await generateImage()
                        }
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isGeneratingImage)
                    
                    Spacer()
                    
                    Button("Chèn vào ghi chú") {
                        insertGeneratedImage()
                    }
                    .disabled(generatedResult == nil || aiService.isGeneratingImage || isInserting)
                }
            }
        }
    }
    
    private func generateImage() async {
        errorMessage = nil
        generatedResult = nil
        
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }
        
        do {
            let result = try await aiService.generateImage(from: trimmedPrompt)
            await MainActor.run {
                self.generatedResult = result
            }
        } catch {
            await MainActor.run {
                if let aiError = error as? AIError {
                    self.errorMessage = aiError.errorDescription
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func insertGeneratedImage() {
        guard let result = generatedResult, !isInserting else { return }
        isInserting = true
        
        let fileExtension: String
        if result.mimeType.contains("png") {
            fileExtension = "png"
        } else if result.mimeType.contains("jpeg") || result.mimeType.contains("jpg") {
            fileExtension = "jpg"
        } else {
            fileExtension = "img"
        }
        
        let fileName = "ai_image_\(Int(Date().timeIntervalSince1970)).\(fileExtension)"
        onInsert(result.data, fileName)
        isInserting = false
        dismiss()
    }
}
