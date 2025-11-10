import SwiftUI
import CoreData
import PhotosUI
import UniformTypeIdentifiers
import WebKit
import Dispatch
#if canImport(UIKit)
import UIKit
#endif

struct UnifiedNoteEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var authManager = AuthManager.shared
    @FocusState private var isContentFocused: Bool

    let note: Note?

    @State private var title = ""
    @State private var content = ""
    @State private var isDraft = false
    @State private var autoSaveTimer: Timer?
    @State private var typingDebounceWorkItem: DispatchWorkItem?
    @State private var currentNote: Note?
    @State private var calculationResult: String? = nil

    // RTF Formatting states
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isUnderline = false
    @State private var showingFormatToolbar = true // Auto-show format toolbar
    @State private var fontSize: CGFloat = EditorPreferences.shared.lastFontSize
    @State private var textColor: Color = .primary
    @State private var webView: WKWebView?

    // Media insertion states
    @State private var showingImagePicker = false
    @State private var showingAIImageGenerator = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingFilePicker = false
    @State private var showingTableInserter = false
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isInserting = false // Prevent dismiss during insert
    @State private var isFormatting = false // Prevent auto-save during formatting
    @State private var isUserTyping = false // Track if user is actively typing
    @State private var isWebViewReady = false // Track if WebView is ready to receive content
    @State private var hasLoadedContent = false // Track if content has been loaded to WebView
    private let editorPreferences = EditorPreferences.shared
    private let autoSaveInactivityInterval: TimeInterval = 60

    init(note: Note? = nil) {
        self.note = note
    }

    var body: some View {
        VStack(spacing: 0) {
            TitleFieldView(title: $title) {
                scheduleAutoSave()
            }
            
            NoteEditorContentView(
                    calculationResult: $calculationResult,
                    showingFormatToolbar: $showingFormatToolbar,
                    content: $content,
                    isBold: isBold,
                    isItalic: isItalic,
                    isUnderline: isUnderline,
                    fontSize: fontSize,
                    textColor: textColor,
                    selectedRange: selectedRange,
                    isContentFocused: $isContentFocused,
                    onContentChange: { newContent in
                        // Only update if content actually changed
                        guard content != newContent else { return }
                        
                        content = newContent
                        detectCalculation(in: newContent)
                        scheduleAutoSaveAfterInactivity()
                    },
                    onListInsert: insertList,
                    onQuoteInsert: insertQuote,
                    onDividerInsert: insertDivider,
                    onDateInsert: insertDate,
                    onTimeInsert: insertTime,
                    onImagePickerShow: { showingImagePicker = true },
                    onAIImageGeneratorShow: { showingAIImageGenerator = true },
                    onTableInserterShow: { showingTableInserter = true },
                    onCalculationAdd: {
                        if let result = calculationResult {
                            content += " = \(result)"
                            calculationResult = nil
                            scheduleAutoSaveAfterInactivity()
                            // Only focus if not inserting
                            if !isInserting {
                                isContentFocused = true
                            }
                        }
                    },
                    onCalculationDismiss: {
                        calculationResult = nil
                    },
                    onUndo: {
                        performUndoAction()
                    },
                    onRedo: {
                        performRedoAction()
                    },
                    onBoldToggle: {
                        applyBoldFormatting()
                    },
                    onItalicToggle: {
                        applyItalicFormatting()
                    },
                    onUnderlineToggle: {
                        applyUnderlineFormatting()
                    },
                    onFontSizeChange: { newSize in
                        print("📏 Font size change requested: \(newSize)")
                        updateFontSizeState(newSize)
                        applyFontSizeFormatting(newSize)
                    },
                    onFontSizeDetected: { detectedSize in
                        // Update UI state when WebView reports font size change
                        if fontSize != detectedSize {
                            updateFontSizeState(detectedSize)
                            print("📏 Font size detected and updated: \(detectedSize)")
                        }
                    },
                    onTextColorChange: { newColor in
                        print("🎨 Text color change requested")
                        // Don't update state here - just apply formatting
                        applyTextColorFormatting(newColor)
                    },
                    onWebViewReady: { wv in
                        webView = wv
                        isWebViewReady = true
                        
                        // Load content immediately when WebView is ready
                        if !hasLoadedContent && !content.isEmpty {
                            loadContentToWebView()
                        }
                    }
                )
        }
        .navigationTitle(note != nil ? "Chỉnh sửa ghi chú" : "Ghi chú mới")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .gesture(
            // Tap gesture to dismiss keyboard when tapping outside editor
            TapGesture().onEnded { _ in
                hideKeyboard()
            }
        )
        .toolbar {
            NoteEditorToolbarContent(
                showingFormatToolbar: $showingFormatToolbar,
                isDraft: $isDraft,
                title: $title,
                currentNote: currentNote,
                onCancel: {
                    cancelAutoSaveTimers()
                    dismiss()
                },
                onSave: {
                    isDraft = false
                    saveNote(shouldDismiss: true)
                }
            )
        }
        .onAppear {
            // Disable auto-sync while viewing/editing note
            syncManager.isViewingNote = true
            
            loadNoteFromLocal()
            
            // If WebView is ready and we have content, load it immediately
            if isWebViewReady && !content.isEmpty && !hasLoadedContent {
                loadContentToWebView()
            }
            
            // Set initial font size
            print("📏 Initial font size: \(Int(fontSize))")
        }
        .onDisappear {
            // Re-enable auto-sync when leaving note
            syncManager.isViewingNote = false
            
            cancelAutoSaveTimers()
            saveNote(isAutoSave: true, force: true)
        }
        .sheet(isPresented: $showingAIImageGenerator) {
            AIImageGeneratorView { imageData, fileName in
                insertAIImage(imageData: imageData, fileName: fileName)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(
                showingCamera: $showingCamera,
                showingPhotoLibrary: $showingPhotoLibrary,
                showingFilePicker: $showingFilePicker,
                selectedImageItem: $selectedImageItem,
                selectedImageData: $selectedImageData,
                onImageSelected: { imageData, fileName in
                    insertImage(imageData: imageData, fileName: fileName)
                }
            )
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(isPresented: $showingCamera) { imageData in
                insertImage(imageData: imageData, fileName: "camera_image.jpg")
            }
        }
        .sheet(isPresented: $showingTableInserter) {
            RTFTableInserter { tableHTML in
                insertTable(tableHTML: tableHTML)
            }
        }
        .onChange(of: isDraft) { _ in
            scheduleAutoSaveAfterInactivity()
        }
        .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedImageItem, matching: .images)
        .onChange(of: selectedImageItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                    insertImage(imageData: data, fileName: "image.jpg")
                }
            }
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let file):
                if file.startAccessingSecurityScopedResource() {
                    do {
                        let data = try Data(contentsOf: file)
                        insertImage(imageData: data, fileName: file.lastPathComponent)
                    } catch {
                        print("Error reading file: \(error)")
                    }
                    file.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                persistDraftOnLifecycleEvent()
            default:
                break
            }
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            persistDraftOnLifecycleEvent()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            persistDraftOnLifecycleEvent()
        }
#endif
    }

    // MARK: - Content Loading Methods
    
    private func loadNoteFromLocal() {
        print("📱 Loading note from local storage...")
        cancelAutoSaveTimers()
        
        if let note = note {
            // Always prioritize local data first
            title = note.title ?? ""
            content = note.content ?? ""
            isDraft = note.isDraft
            currentNote = note
            
            print("✅ Local note loaded - Title: '\(title)'")
            print("✅ Local content length: \(content.count) characters")
            print("✅ Content preview: \(content.prefix(100))")
            
            // If WebView is ready, load content immediately
            if isWebViewReady && !content.isEmpty {
                loadContentToWebView()
            }
            
            // Check for server updates in background (non-blocking)
            checkForServerUpdates()
            
        } else {
            // New note
            title = ""
            content = ""
            isDraft = true
            currentNote = nil
            hasLoadedContent = false
            print("� Creating new note")
        }
    }
    
    private func loadContentToWebView() {
        guard let webView = webView, 
              isWebViewReady, 
              !content.isEmpty,
              !hasLoadedContent else { 
            print("⚠️ Cannot load content to WebView - conditions not met")
            return 
        }
        
        print("🌐 Loading content to WebView...")
        
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        
        let script = "document.body.innerHTML = '\(escapedContent)';"
        
        webView.evaluateJavaScript(script) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading content to WebView: \(error)")
                } else {
                    print("✅ Content successfully loaded to WebView")
                    self.hasLoadedContent = true
                }
            }
        }
    }
    
    private func checkForServerUpdates() {
        guard let note = currentNote,
              authManager.isLoggedIn,
              !note.needsSync else { 
            print("📡 Skipping server check - not logged in or note needs sync")
            return 
        }
        
        print("📡 Checking server for updates...")
        
        // Check for server updates in background (non-blocking)
        Task {
            await syncManager.checkForUpdates(for: note) { updatedNote in
                DispatchQueue.main.async {
                    // Only update if content actually changed on server
                    if updatedNote.content != self.content {
                        print("🔄 Server has newer content, updating...")
                        self.content = updatedNote.content ?? ""
                        self.title = updatedNote.title ?? ""
                        
                        // Reload content to WebView if it's different
                        if self.isWebViewReady {
                            self.hasLoadedContent = false
                            self.loadContentToWebView()
                        }
                    }
                }
            }
        }
    }

    private func scheduleAutoSave() {
        scheduleAutoSaveAfterInactivity()
    }

    private func scheduleAutoSaveAfterInactivity() {
        typingDebounceWorkItem?.cancel()
        cancelAutoSaveTimers()
        
        guard hasPendingChanges() else {
            isUserTyping = false
            return
        }
        
        isUserTyping = true
        
        let workItem = DispatchWorkItem { [self] in
            self.isUserTyping = false
            self.startAutoSaveTimer()
        }
        typingDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func startAutoSaveTimer(after interval: TimeInterval? = nil) {
        let delay = interval ?? autoSaveInactivityInterval
        guard delay > 0 else { return }
        
        // Don't start timer if user is actively working
        if isInserting || isFormatting || isUserTyping || showingFormatToolbar {
            print("⏸️ Auto-save timer skipped - user is active")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startAutoSaveTimer(after: delay)
            }
            return
        }
        
        cancelAutoSaveTimers()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            self.performAutoSave()
        }
    }

    private func hasPendingChanges() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentContent = content

        if let existingNote = currentNote {
            let existingTitle = existingNote.title ?? ""
            let existingContent = existingNote.content ?? ""
            if existingTitle != trimmedTitle { return true }
            if existingContent != currentContent { return true }
            if existingNote.isDraft != isDraft { return true }
            return false
        } else {
            let trimmedContent = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedTitle.isEmpty || !trimmedContent.isEmpty
        }
    }

    private func performAutoSave() {
        cancelAutoSaveTimers()
        saveNote(isAutoSave: true)
    }

    private func cancelAutoSaveTimers() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        typingDebounceWorkItem?.cancel()
        typingDebounceWorkItem = nil
    }

    private func saveNote(
        isAutoSave: Bool = false,
        shouldDismiss: Bool = false,
        force: Bool = false
    ) {
        if !isAutoSave {
            cancelAutoSaveTimers()
            isUserTyping = false
        }
        
        if isAutoSave && !force && (isUserTyping || isInserting || isFormatting || showingFormatToolbar) {
            print("⏸️ Auto-save blocked - user active (typing: \(isUserTyping), inserting: \(isInserting), formatting: \(isFormatting), toolbar: \(showingFormatToolbar))")
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else { return }
        let normalizedTitle = trimmedTitle.isEmpty ? nil : trimmedTitle
        let allowEmptyTitle = normalizedTitle == nil

        if let existingNote = currentNote {
            let hasChanges = existingNote.title != normalizedTitle ||
                           existingNote.content != content ||
                           existingNote.isDraft != isDraft

            if hasChanges {
                coreDataManager.updateNote(
                    existingNote,
                    title: normalizedTitle,
                    content: content,
                    isDraft: isDraft,
                    allowEmptyTitle: allowEmptyTitle
                )

                do {
                    try viewContext.save()
                } catch {
                    print("Error saving note: \(error)")
                }

                if !isAutoSave && authManager.isLoggedIn && !isDraft {
                    Task {
                        await syncManager.syncNote(existingNote)
                    }
                }
            }

            if shouldDismiss {
                dismiss()
            }
        } else {
            let newNote = coreDataManager.createNote(
                title: normalizedTitle,
                content: content,
                isDraft: isDraft
            )

            do {
                try viewContext.save()
            } catch {
                print("Error saving note: \(error)")
            }

            currentNote = newNote

            if !isAutoSave && authManager.isLoggedIn && !isDraft {
                Task {
                    await syncManager.syncNote(newNote)
                }
            }

            if shouldDismiss {
                dismiss()
            }
        }
        
        isUserTyping = false
    }
    
    private func persistDraftOnLifecycleEvent() {
        saveNote(isAutoSave: true, force: true)
    }

    private func detectCalculation(in text: String) {
        calculationResult = nil

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
                    break
                }
            }
        }
    }

    private func calculateExpression(_ expression: String) -> Double? {
        let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
        let expr = NSExpression(format: cleanExpression)

        do {
            if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
                return result.doubleValue
            }
        } catch {
            // Silent fail
        }

        return nil
    }

    private func formatResult(_ result: Double) -> String {
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(result))
        } else {
            return String(format: "%.2f", result).replacingOccurrences(of: ".00", with: "")
        }
    }

        // MARK: - RTF Formatting Functions

    private func insertAIImage(imageData: Data, fileName: String) {
        showingAIImageGenerator = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.insertImage(imageData: imageData, fileName: fileName)
        }
    }

    private func insertImage(imageData: Data, fileName: String) {
        // Prevent duplicate inserts
        guard !isInserting else { return }
        isInserting = true
        
        // Dismiss all pickers first
        showingImagePicker = false
        showingCamera = false
        showingPhotoLibrary = false
        showingFilePicker = false
        
        // Wait a moment for sheet to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            defer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isInserting = false
                }
            }
            
            let base64String = imageData.base64EncodedString()
            let fileExtension = fileName.split(separator: ".").last.map { String($0).lowercased() } ?? ""
            let mimeType: String
            switch fileExtension {
            case "jpg", "jpeg":
                mimeType = "image/jpeg"
            case "gif":
                mimeType = "image/gif"
            case "webp":
                mimeType = "image/webp"
            case "heic":
                mimeType = "image/heic"
            default:
                mimeType = "image/png"
            }
            
            let imageTag = "<img src=\"data:\(mimeType);base64,\(base64String)\" alt=\"\(fileName)\" style=\"max-width: 100%; height: auto;\">"
            
            guard let webView = self.webView else { 
                self.content += imageTag
                scheduleAutoSaveAfterInactivity()
                return 
            }
            
            let escapedHTML = imageTag.replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("insertHTML('\(escapedHTML)')") { _, error in
                if let error = error {
                    print("Error inserting image: \(error)")
                }
            }
        }
    }

    private func insertTable(tableHTML: String) {
        // Prevent duplicate inserts
        guard !isInserting else { return }
        isInserting = true
        
        // Dismiss table inserter
        showingTableInserter = false
        
        // Wait a moment for sheet to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            defer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isInserting = false
                }
            }
            
            guard let webView = self.webView else { 
                self.content += tableHTML
                scheduleAutoSaveAfterInactivity()
                return 
            }
            
            let escapedHTML = tableHTML.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "")
            webView.evaluateJavaScript("insertHTML('\(escapedHTML)')") { _, error in
                if let error = error {
                    print("Error inserting table: \(error)")
                    // Don't add to content here as fallback - WebView should handle it
                }
            }
        }
    }

    private func insertList() {
        // Prevent duplicate inserts
        guard !isInserting else { return }
        isInserting = true
        
        let listHTML = "<ul><li>Mục 1</li><li>Mục 2</li><li>Mục 3</li></ul>"
        
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInserting = false
            }
        }
        
        guard let webView = webView else { 
            content += listHTML
            scheduleAutoSaveAfterInactivity()
            return 
        }
        
        webView.evaluateJavaScript("insertHTML('\(listHTML)')") { _, error in
            if let error = error {
                print("Error inserting list: \(error)")
            }
        }
    }

    private func insertQuote() {
        // Prevent duplicate inserts
        guard !isInserting else { return }
        isInserting = true
        
        let quoteHTML = "<blockquote>Trích dẫn của bạn</blockquote>"
        
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInserting = false
            }
        }
        
        guard let webView = webView else { 
            content += quoteHTML
            scheduleAutoSaveAfterInactivity()
            return 
        }
        
        webView.evaluateJavaScript("insertHTML('\(quoteHTML)')") { _, error in
            if let error = error {
                print("Error inserting quote: \(error)")
            }
        }
    }

    private func insertDivider() {
        // Prevent duplicate inserts
        guard !isInserting else { return }
        isInserting = true
        
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInserting = false
            }
        }
        
        guard let webView = webView else { 
            content += "<hr>"
            scheduleAutoSaveAfterInactivity()
            return 
        }
        
        webView.evaluateJavaScript("insertHTML('<hr>')") { _, error in
            if let error = error {
                print("Error inserting divider: \(error)")
            }
        }
    }

    private func insertDate() {
        // Prevent duplicate inserts
        guard !isInserting else { return }
        isInserting = true
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "vi_VN")
        let dateHTML = "<p>📅 \(formatter.string(from: Date()))</p>"
        
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInserting = false
            }
        }
        
        guard let webView = webView else { 
            content += dateHTML
            scheduleAutoSaveAfterInactivity()
            return 
        }
        
        webView.evaluateJavaScript("insertHTML('\(dateHTML)')") { _, error in
            if let error = error {
                print("Error inserting date: \(error)")
            }
        }
    }

    private func insertTime() {
        // Prevent duplicate inserts
        guard !isInserting else { return }
        isInserting = true
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeHTML = "<p>⏰ \(formatter.string(from: Date()))</p>"
        
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInserting = false
            }
        }
        
        guard let webView = webView else { 
            content += timeHTML
            scheduleAutoSaveAfterInactivity()
            return 
        }
        
        webView.evaluateJavaScript("insertHTML('\(timeHTML)')") { _, error in
            if let error = error {
                print("Error inserting time: \(error)")
            }
        }
    }
    
    // MARK: - Formatting Helper Functions
    
    private func applyBoldFormatting() {
        guard let webView = webView, isWebViewReady else { 
            print("❌ WebView not ready for bold formatting")
            return 
        }
        print("🔥 Applying bold formatting")
        
        // Set formatting flag to prevent auto-save
        isFormatting = true
        
        // First test if JavaScript is ready
        webView.evaluateJavaScript("typeof applyFormatting") { result, error in
            if let result = result as? String, result == "function" {
                // JavaScript function exists, now apply formatting
                webView.evaluateJavaScript("applyFormatting('bold')") { formatResult, formatError in
                    if let formatError = formatError {
                        print("❌ Bold formatting error: \(formatError)")
                    } else {
                        print("✅ Bold formatting applied successfully")
                    }
                    
                    // Reset formatting flag after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isFormatting = false
                    }
                }
            } else {
                print("❌ applyFormatting function not available in WebView")
                // Reset flag if function not available
                self.isFormatting = false
            }
        }
    }
    
    private func applyItalicFormatting() {
        guard let webView = webView, isWebViewReady else { 
            print("❌ WebView not ready for italic formatting")
            return 
        }
        print("🔥 Applying italic formatting")
        
        // Set formatting flag to prevent auto-save
        isFormatting = true
        
        webView.evaluateJavaScript("typeof applyFormatting") { result, error in
            if let result = result as? String, result == "function" {
                webView.evaluateJavaScript("applyFormatting('italic')") { formatResult, formatError in
                    if let formatError = formatError {
                        print("❌ Italic formatting error: \(formatError)")
                    } else {
                        print("✅ Italic formatting applied successfully")
                    }
                    
                    // Reset formatting flag after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isFormatting = false
                    }
                }
            } else {
                print("❌ applyFormatting function not available in WebView")
                // Reset flag if function not available
                self.isFormatting = false
            }
        }
    }
    
    private func applyUnderlineFormatting() {
        guard let webView = webView, isWebViewReady else { 
            print("❌ WebView not ready for underline formatting")
            return 
        }
        print("🔥 Applying underline formatting")
        
        // Set formatting flag to prevent auto-save
        isFormatting = true
        
        webView.evaluateJavaScript("typeof applyFormatting") { result, error in
            if let result = result as? String, result == "function" {
                webView.evaluateJavaScript("applyFormatting('underline')") { formatResult, formatError in
                    if let formatError = formatError {
                        print("❌ Underline formatting error: \(formatError)")
                    } else {
                        print("✅ Underline formatting applied successfully")
                    }
                    
                    // Reset formatting flag after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isFormatting = false
                    }
                }
            } else {
                print("❌ applyFormatting function not available in WebView")
                // Reset flag if function not available
                self.isFormatting = false
            }
        }
    }
    
    private func updateFontSizeState(_ newSize: CGFloat) {
        let clampedSize = min(max(newSize, 8), 48)
        fontSize = clampedSize
        editorPreferences.lastFontSize = clampedSize
    }
    
    private func applyFontSizeFormatting(_ size: CGFloat) {
        guard let webView = webView, isWebViewReady else { 
            print("❌ WebView not ready for font size formatting")
            return 
        }
        
        print("🔧 Applying font size: \(Int(size))")
        
        webView.evaluateJavaScript("typeof setFontSize") { result, error in
            if let result = result as? String, result == "function" {
                webView.evaluateJavaScript("setFontSize(\(Int(size)))") { formatResult, formatError in
                    if let formatError = formatError {
                        print("❌ Font size error: \(formatError)")
                    } else {
                        print("✅ Font size applied successfully: \(Int(size))")
                    }
                }
            } else {
                print("❌ setFontSize function not available in WebView")
            }
        }
    }
    
    private func applyTextColorFormatting(_ color: Color) {
        guard let webView = webView, isWebViewReady else { 
            print("❌ WebView not ready for text color formatting")
            return 
        }
        
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hexColor = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        
        print("🎨 Applying text color: \(hexColor)")
        
        webView.evaluateJavaScript("typeof setTextColor") { result, error in
            if let result = result as? String, result == "function" {
                webView.evaluateJavaScript("setTextColor('\(hexColor)')") { formatResult, formatError in
                    if let formatError = formatError {
                        print("❌ Text color error: \(formatError)")
                    } else {
                        print("✅ Text color applied successfully: \(hexColor)")
                    }
                }
            } else {
                print("❌ setTextColor function not available in WebView")
            }
        }
    }
    
    private func performUndoAction() {
        guard let webView = webView, isWebViewReady else {
            print("❌ WebView not ready for undo")
            return
        }
        
        webView.evaluateJavaScript("document.execCommand('undo')") { _, error in
            if let error = error {
                print("❌ Undo action failed: \(error)")
            } else {
                print("↩️ Undo performed")
            }
        }
    }
    
    private func performRedoAction() {
        guard let webView = webView, isWebViewReady else {
            print("❌ WebView not ready for redo")
            return
        }
        
        webView.evaluateJavaScript("document.execCommand('redo')") { _, error in
            if let error = error {
                print("❌ Redo action failed: \(error)")
            } else {
                print("↪️ Redo performed")
            }
        }
    }
    
    // MARK: - Keyboard Helper
    
    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Preview
#Preview {
    UnifiedNoteEditView()
}
