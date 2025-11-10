//
//  AIPromptView.swift
//  PPNote
//
//  Created by Phát Phạm on 22/10/25.
//

import SwiftUI
import Foundation

struct AIPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = AIService.shared
    @StateObject private var coreDataManager = CoreDataManager.shared
    @FocusState private var isTextEditorFocused: Bool
    
    @State private var prompt = ""
    @State private var generatedTitle = ""
    @State private var generatedContent = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasGenerated = false
    @State private var calculationResult: String? = nil
    
    private var previewContentText: String {
        var preview = generatedContent
        if preview.hasPrefix("* ") {
            preview = "• " + preview.dropFirst(2)
        }
        preview = preview.replacingOccurrences(of: "\n* ", with: "\n• ")
        preview = preview.replacingOccurrences(of: "\n- ", with: "\n• ")
        preview = preview.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        return preview.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        ZStack {
            // Background gradient - similar to LoginView
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            NavigationView {
                VStack(spacing: 20) {
                    // Header Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 35, weight: .light))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Tạo ghi chú AI")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                            
                            Text("Mô tả ghi chú bạn muốn tạo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Prompt Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("Nội dung")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    
                        TextEditor(text: $prompt)
                            .frame(minHeight: 100, maxHeight: 150)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(prompt.isEmpty ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
                            )
                            .focused($isTextEditorFocused)
                            .onChange(of: prompt) { newValue in
                                detectCalculation(in: newValue)
                            }
                        
                        // Calculation hint
                        if let result = calculationResult {
                            HStack {
                                Image(systemName: "equal.circle.fill")
                                    .foregroundColor(.green)
                                Text("Kết quả: \(result)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                
                                Spacer()
                                
                                Button(action: {
                                    prompt += " = \(result)"
                                    calculationResult = nil
                                }) {
                                    Text("Thêm")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .transition(.slide.combined(with: .opacity))
                        }
                        
                        Text("Ví dụ: Kế hoạch học tập tuần này, 15+25*2, Danh sách mua sắm...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 30)
                
                    // Generate Button
                    Button(action: generateNote) {
                        HStack {
                            if aiService.isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(aiService.isGenerating ? "AI đang soạn..." : "Tạo ghi chú với AI")
                                .fontWeight(.semibold)
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
                    .disabled(!isFormValid || aiService.isGenerating)
                    .padding(.horizontal, 30)
                
                        // Generated Content Section
                    if hasGenerated {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.green)
                                    Text("Ghi chú được tạo")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            
                                if !generatedTitle.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "textformat")
                                                .foregroundColor(.blue)
                                                .frame(width: 16)
                                            Text("Tiêu đề:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(generatedTitle)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                    }
                                }
                                
                                if !generatedContent.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "doc.plaintext")
                                                .foregroundColor(.blue)
                                                .frame(width: 16)
                                            Text("Nội dung:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(previewContentText)
                                            .font(.system(.body, design: .default))
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .padding(.horizontal, 30)
                        }
                        .onTapGesture {
                            isTextEditorFocused = false
                        }                        // Save Button
                        Button(action: saveNote) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Lưu ghi chú")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green, Color.blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal, 30)
                    }
                    
                    Spacer()
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text("Hủy")
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isTextEditorFocused = false
        }
        .animation(.easeInOut(duration: 0.3), value: hasGenerated)
        .animation(.easeInOut(duration: 0.3), value: calculationResult)
        .alert("Lỗi", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func generateNote() {
        Task {
            do {
                let response = try await aiService.generateNoteContent(from: prompt)
                
                await MainActor.run {
                    parseAIResponse(response)
                    hasGenerated = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func parseAIResponse(_ response: String) {
        // Clean and normalize the response
        let cleanedResponse = cleanAIResponse(response)
        
        let lines = cleanedResponse.components(separatedBy: .newlines)
        var title = ""
        var content = ""
        var isContent = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("TITLE:") {
                title = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmedLine.hasPrefix("CONTENT:") {
                content = String(trimmedLine.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
                isContent = true
            } else if isContent {
                if !content.isEmpty && !trimmedLine.isEmpty {
                    content += "\n" + line // Preserve original line formatting
                } else if !trimmedLine.isEmpty {
                    content += line
                } else {
                    content += "\n"
                }
            }
        }
        
        // Fallback if parsing fails
        if title.isEmpty && content.isEmpty {
            // Try to extract first line as title
            let responseLines = cleanedResponse.components(separatedBy: .newlines)
            if let firstLine = responseLines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstLine.isEmpty {
                title = firstLine
                content = responseLines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                title = "Ghi chú AI"
                content = cleanedResponse
            }
        }
        
        generatedTitle = title.isEmpty ? "Ghi chú AI" : title
        
        let baseContent = content.isEmpty ? cleanedResponse : content
        let normalizedContent = normalizeAIContent(baseContent)
        let previewLines = normalizedContent
            .components(separatedBy: .newlines)
            .flatMap { splitInlineSegments(from: $0) }
        
        if previewLines.isEmpty {
            generatedContent = baseContent
        } else {
            var combinedLines: [String] = []
            for segment in previewLines {
                let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedSegment.isEmpty else { continue }
                
                if trimmedSegment.hasPrefix("* ") {
                    let bulletText = String(trimmedSegment.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if shouldAppendToPreviousBullet(bulletText),
                       let lastIndex = combinedLines.indices.last,
                       combinedLines[lastIndex].hasPrefix("* ") {
                        combinedLines[lastIndex] += " * " + bulletText
                        continue
                    }
                    combinedLines.append("* " + bulletText)
                } else {
                    combinedLines.append(trimmedSegment)
                }
            }
            
            generatedContent = combinedLines.joined(separator: "\n")
        }
    }
    
    private func cleanAIResponse(_ response: String) -> String {
        // Remove markdown-style bold markers and other unwanted characters
        var cleaned = response
        
        // Remove ** bold markers
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        
        // Clean up excessive spaces while preserving structure
        let lines = cleaned.components(separatedBy: .newlines)
        let cleanedLines = lines.map { line in
            // Keep original line structure but clean up leading/trailing spaces
            return line.trimmingCharacters(in: .whitespaces)
        }
        
        return cleanedLines.joined(separator: "\n")
    }
    
    private func normalizeAIContent(_ content: String) -> String {
        var normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\t", with: " ")
        
        // Break inline bullet points into separate lines
        normalized = normalized.replacingOccurrences(of: ": *", with: ":\n* ")
        normalized = normalized.replacingOccurrences(of: "•", with: "*")
        
        // Ensure numbered steps appear on new lines
        for number in 1...20 {
            normalized = normalized.replacingOccurrences(of: " \(number).", with: "\n\(number).")
        }
        
        // Ensure Roman numeral sections appear on new lines
        let romanSections = ["I.", "II.", "III.", "IV.", "V.", "VI.", "VII.", "VIII.", "IX.", "X."]
        for section in romanSections {
            normalized = normalized.replacingOccurrences(of: " \(section)", with: "\n\(section)")
        }
        
        // Collapse excessive blank lines
        while normalized.contains("\n\n\n") {
            normalized = normalized.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func splitInlineSegments(from line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("*") else {
            return trimmed.isEmpty ? [] : [trimmed]
        }
        
        guard let regex = try? NSRegularExpression(pattern: "\\*\\s+[^*]+", options: []) else {
            return trimmed.isEmpty ? [] : [trimmed]
        }
        
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        
        if matches.isEmpty {
            return trimmed.isEmpty ? [] : [trimmed]
        }
        
        var segments: [String] = []
        var currentLocation = 0
        
        for match in matches {
            if match.range.location > currentLocation {
                let prefixRange = NSRange(location: currentLocation, length: match.range.location - currentLocation)
                let prefix = nsLine.substring(with: prefixRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefix.isEmpty {
                    segments.append(prefix)
                }
            }
            
            let segment = nsLine.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty {
                segments.append(segment)
            }
            
            currentLocation = match.range.location + match.range.length
        }
        
        if currentLocation < nsLine.length {
            let suffix = nsLine.substring(from: currentLocation).trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty {
                segments.append(suffix)
            }
        }
        
        return segments
    }
    
    private func formatContentForRichText(_ content: String) -> String {
        let normalized = normalizeAIContent(content)
        guard !normalized.isEmpty else { return "" }
        
        let baseLines = normalized.components(separatedBy: .newlines)
        let lines = baseLines.flatMap { splitInlineSegments(from: $0) }
        var htmlParts: [String] = []
        var isInUnorderedList = false
        var isInOrderedList = false
        
        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                if isInUnorderedList {
                    htmlParts.append("</ul>")
                    isInUnorderedList = false
                }
                if isInOrderedList {
                    htmlParts.append("</ol>")
                    isInOrderedList = false
                }
                continue
            }
            
            if matchesRomanHeading(trimmed) {
                if isInUnorderedList {
                    htmlParts.append("</ul>")
                    isInUnorderedList = false
                }
                if isInOrderedList {
                    htmlParts.append("</ol>")
                    isInOrderedList = false
                }
                htmlParts.append("<h3>\(escapeHTML(trimmed))</h3>")
                continue
            }
            
            if isOrderedListItem(trimmed) {
                if isInUnorderedList {
                    htmlParts.append("</ul>")
                    isInUnorderedList = false
                }
                if !isInOrderedList {
                    htmlParts.append("<ol>")
                    isInOrderedList = true
                }
                
                let itemText = orderedText(from: trimmed)
                htmlParts.append("<li>\(formatListItemText(itemText))</li>")
                continue
            }
            
            if isBulletItem(trimmed) {
                if !isInUnorderedList {
                    htmlParts.append("<ul>")
                    isInUnorderedList = true
                }
                
                let bullet = bulletText(from: trimmed)
                let trimmedBullet = bullet.trimmingCharacters(in: .whitespaces)
                
                if shouldAppendToPreviousBullet(trimmedBullet),
                   let lastIndex = htmlParts.indices.last,
                   htmlParts[lastIndex].hasPrefix("<li>") {
                    let appended = htmlParts[lastIndex].replacingOccurrences(of: "</li>", with: " * \(escapeHTML(trimmedBullet))</li>")
                    htmlParts[lastIndex] = appended
                    continue
                }
                
                htmlParts.append("<li>\(formatListItemText(trimmedBullet))</li>")
                continue
            }
            
            if isInUnorderedList {
                htmlParts.append("</ul>")
                isInUnorderedList = false
            }
            if isInOrderedList {
                htmlParts.append("</ol>")
                isInOrderedList = false
            }
            
            htmlParts.append("<p>\(formatListItemText(trimmed))</p>")
        }
        
        if isInUnorderedList {
            htmlParts.append("</ul>")
        }
        if isInOrderedList {
            htmlParts.append("</ol>")
        }
        
        return "<div class=\"ai-generated-note\">\n\(htmlParts.joined(separator: "\n"))\n</div>"
    }
    
    private func escapeHTML(_ text: String) -> String {
        var escaped = text.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }
    
    private func formatListItemText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        guard let colonIndex = trimmed.firstIndex(of: ":") else {
            return escapeHTML(trimmed)
        }
        
        let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let valueStart = trimmed.index(after: colonIndex)
        let value = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let escapedKey = escapeHTML(key)
        let escapedValue = escapeHTML(value)
        
        if escapedValue.isEmpty {
            return "<strong>\(escapedKey)</strong>"
        } else {
            return "<strong>\(escapedKey):</strong> \(escapedValue)"
        }
    }
    
    private func matchesRomanHeading(_ line: String) -> Bool {
        let pattern = #"^[IVXLCDM]+\.\s"# 
        return line.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func isOrderedListItem(_ line: String) -> Bool {
        let pattern = #"^\d+\.\s"# 
        return line.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func orderedText(from line: String) -> String {
        guard let dotIndex = line.firstIndex(of: ".") else { return line }
        let nextIndex = line.index(after: dotIndex)
        return String(line[nextIndex...]).trimmingCharacters(in: .whitespaces)
    }
    
    private func isBulletItem(_ line: String) -> Bool {
        return line.hasPrefix("* ") || line.hasPrefix("- ") || line.hasPrefix("• ")
    }
    
    private func bulletText(from line: String) -> String {
        if line.hasPrefix("* ") || line.hasPrefix("- ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("• ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return line
    }
    
    private func shouldAppendToPreviousBullet(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return true
        }
        
        if trimmed.count <= 2 {
            return true
        }
        
        if let first = trimmed.first, first.isNumber {
            let containsMathSymbol = trimmed.contains("=") || trimmed.contains("/") || trimmed.contains("*")
            return containsMathSymbol
        }
        
        return false
    }
    
    private var isFormValid: Bool {
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Calculator Functions
    
    private func detectCalculation(in text: String) {
        // Reset calculation result first
        calculationResult = nil
        
        // Look for mathematical expressions
        let mathPattern = #"(?:^|\s)([0-9]+(?:\.[0-9]+)?(?:\s*[+\-*/]\s*[0-9]+(?:\.[0-9]+)?)+)(?:\s|$)"#
        
        guard let regex = try? NSRegularExpression(pattern: mathPattern, options: []) else { return }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let expression = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let result = calculateExpression(expression) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        calculationResult = formatResult(result)
                    }
                    break // Only show the first valid calculation
                }
            }
        }
    }
    
    private func calculateExpression(_ expression: String) -> Double? {
        // Clean the expression
        let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
        
        // Use NSExpression for safe calculation
        let expr = NSExpression(format: cleanExpression)
        
        do {
            if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
                return result.doubleValue
            }
        } catch {
            // Silent fail for invalid expressions
        }
        
        return nil
    }
    
    private func formatResult(_ result: Double) -> String {
        // Format the result nicely
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(result))
        } else {
            return String(format: "%.2f", result).replacingOccurrences(of: ".00", with: "")
        }
    }
    
    private func saveNote() {
        let finalTitle = generatedTitle.isEmpty ? "Ghi chú AI" : generatedTitle
        let finalContent = generatedContent.isEmpty ? prompt : generatedContent
        
        // Clean and format the content before saving to ensure proper display
        let cleanedTitle = finalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedContent = finalContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedHTML = formatContentForRichText(cleanedContent)
        let contentToSave = formattedHTML.isEmpty ? "<p>\(escapeHTML(cleanedContent))</p>" : formattedHTML
        
        coreDataManager.createNote(title: cleanedTitle, content: contentToSave)
        dismiss()
    }
}

#Preview {
    AIPromptView()
}
