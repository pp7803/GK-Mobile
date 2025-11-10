import SwiftUI
import WebKit

// MARK: - Rich Text Editor with direct HTML editing
struct RichTextEditor: UIViewRepresentable {
    @Binding var htmlContent: String
    // Changed from @Binding to regular properties - these are read-only states
    // that should NOT trigger view updates when changed
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var fontSize: CGFloat
    var textColor: Color
    var selectedRange: NSRange
    
    let onContentChange: (String) -> Void
    let onTableInsert: () -> Void
    let onListInsert: () -> Void
    let onQuoteInsert: () -> Void
    let onDividerInsert: () -> Void
    let onBoldToggle: () -> Void
    let onItalicToggle: () -> Void
    let onUnderlineToggle: () -> Void
    let onFontSizeChange: (CGFloat) -> Void
    let onFontSizeDetected: (CGFloat) -> Void
    let onWebViewReady: (WKWebView) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        
        // Prevent webView from losing focus and enable better interaction
        webView.scrollView.keyboardDismissMode = .none
        webView.allowsBackForwardNavigationGestures = false
        
        // Enable selection and editing
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView.configuration.preferences.javaScriptEnabled = true
        
        // Enable content editing
        webView.configuration.userContentController.add(context.coordinator, name: "contentChange")
        webView.configuration.userContentController.add(context.coordinator, name: "tableInsert")
        webView.configuration.userContentController.add(context.coordinator, name: "formattingState")
        
        // Notify parent that webView is ready
        DispatchQueue.main.async {
            self.onWebViewReady(webView)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Load HTML template on first load
        if !context.coordinator.hasLoadedInitialContent {
            context.coordinator.hasLoadedInitialContent = true
            context.coordinator.lastContent = htmlContent
            loadHTMLTemplate(uiView)
            return
        } 
        
        // Update content if it changed and webView is loaded (but not from user typing)
        if context.coordinator.lastContent != htmlContent && 
           !context.coordinator.isUserTyping &&
           context.coordinator.isWebViewLoaded {
            print("🔄 Content changed, updating WebView...")
            context.coordinator.lastContent = htmlContent
            loadContent(uiView)
        }
    }
    
    private func loadHTMLTemplate(_ webView: WKWebView) {
        
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                :root {
                    color-scheme: light dark;
                }
                
                * {
                    -webkit-tap-highlight-color: transparent;
                    outline: 0;
                }
                
                html {
                    height: 100%;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    margin: 0;
                    padding: 16px;
                    color: #111;
                    font-size: 16px;
                    min-height: 100%;
                    background-color: transparent;
                }
                
                p {
                    margin-top: 0;
                    margin-bottom: 16px;
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 12px 0;
                }
                
                table {
                    border-collapse: collapse;
                    margin: 12px 0;
                    width: 100%;
                }
                
                table, th, td {
                    border: 1px solid #ddd;
                }
                
                th, td {
                    padding: 8px;
                    text-align: left;
                }
                
                blockquote {
                    border-left: 4px solid #ddd;
                    padding-left: 16px;
                    margin-left: 0;
                    color: #555;
                    font-style: italic;
                }
                
                hr {
                    border: none;
                    height: 1px;
                    background-color: #ddd;
                    margin: 16px 0;
                }
                
                ul, ol {
                    margin-top: 0;
                    margin-bottom: 16px;
                    padding-left: 30px;
                }
                
                li {
                    margin-bottom: 8px;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #f5f5f5;
                    }
                    
                    blockquote {
                        border-left-color: rgba(255, 255, 255, 0.35);
                        color: rgba(255, 255, 255, 0.8);
                    }
                    
                    hr {
                        background-color: rgba(255, 255, 255, 0.3);
                    }
                    
                    table, th, td {
                        border-color: rgba(255, 255, 255, 0.25);
                    }
                }
            </style>
            <script>
                // Store the current selection range
                let savedRange = null;
                
                document.addEventListener('DOMContentLoaded', function() {
                    // Ensure document is editable
                    document.designMode = 'on';
                    document.body.contentEditable = 'true';
                    
                    // Test formatting capabilities
                    testFormatting();
                    
                    document.body.addEventListener('input', function() {
                        // Send content to Swift
                        window.webkit.messageHandlers.contentChange.postMessage(document.body.innerHTML);
                        
                        // Update formatting state
                        updateFormattingState();
                    });
                });
                
                function saveSelection() {
                    const selection = window.getSelection();
                    if (selection.rangeCount > 0) {
                        savedRange = selection.getRangeAt(0);
                    }
                }
                
                function restoreSelection() {
                    if (savedRange) {
                        const selection = window.getSelection();
                        selection.removeAllRanges();
                        selection.addRange(savedRange);
                    }
                }
                
                function forceRefresh() {
                    // Force DOM to refresh by triggering a repaint
                    const body = document.body;
                    const display = body.style.display;
                    body.style.display = 'none';
                    body.offsetHeight; // Trigger reflow
                    body.style.display = display;
                }
                
                function testFormatting() {
                    console.log('🧪 Testing formatting capabilities:');
                    console.log('- designMode:', document.designMode);
                    console.log('- contentEditable:', document.body.contentEditable);
                    console.log('- execCommand support:');
                    console.log('  - bold:', document.queryCommandSupported('bold'));
                    console.log('  - italic:', document.queryCommandSupported('italic'));
                    console.log('  - underline:', document.queryCommandSupported('underline'));
                    console.log('- Current HTML:', document.body.innerHTML.substring(0, 100) + '...');
                }
                
                function getCurrentFontSize() {
                    const selection = window.getSelection();
                    let fontSize = 16; // Default
                    
                    if (selection && selection.rangeCount > 0) {
                        const range = selection.getRangeAt(0);
                        let element = range.startContainer;
                        
                        // Find the parent element if text node
                        if (element.nodeType === Node.TEXT_NODE) {
                            element = element.parentElement;
                        }
                        
                        // Get computed font size
                        if (element) {
                            const computedStyle = window.getComputedStyle(element);
                            fontSize = parseInt(computedStyle.fontSize);
                        }
                    } else {
                        // No selection, get body font size
                        const bodyStyle = window.getComputedStyle(document.body);
                        fontSize = parseInt(bodyStyle.fontSize);
                    }
                    
                    return fontSize || 16;
                }
                
                function updateFormattingState() {
                    const selection = window.getSelection();
                    const hasSelection = selection && selection.toString().length > 0;
                    const currentFontSize = getCurrentFontSize();
                    
                    // Try multiple methods to detect formatting
                    let isBold = false;
                    let isItalic = false;
                    let isUnderline = false;
                    
                    try {
                        // Method 1: queryCommandState
                        isBold = document.queryCommandState('bold');
                        isItalic = document.queryCommandState('italic');
                        isUnderline = document.queryCommandState('underline');
                        
                        // Method 2: Check parent elements if selection exists
                        if (hasSelection) {
                            const range = selection.getRangeAt(0);
                            let node = range.commonAncestorContainer;
                            
                            // Walk up the DOM tree to check for formatting elements
                            while (node && node.nodeType !== Node.DOCUMENT_NODE) {
                                if (node.nodeType === Node.ELEMENT_NODE) {
                                    const tagName = node.tagName ? node.tagName.toLowerCase() : '';
                                    const style = node.style || {};
                                    
                                    if (tagName === 'b' || tagName === 'strong' || style.fontWeight === 'bold' || style.fontWeight === '700') {
                                        isBold = true;
                                    }
                                    if (tagName === 'i' || tagName === 'em' || style.fontStyle === 'italic') {
                                        isItalic = true;
                                    }
                                    if (tagName === 'u' || style.textDecoration && style.textDecoration.includes('underline')) {
                                        isUnderline = true;
                                    }
                                }
                                node = node.parentNode;
                            }
                        }
                        
                    } catch (e) {
                        console.log('Error checking formatting state:', e);
                    }
                    
                    const state = {
                        bold: isBold,
                        italic: isItalic,
                        underline: isUnderline,
                        hasSelection: hasSelection,
                        fontSize: currentFontSize
                    };
                    
                    console.log('📊 Formatting state:', state);
                    window.webkit.messageHandlers.formattingState.postMessage(JSON.stringify(state));
                }
                
                // Listen for selection changes and content changes
                document.addEventListener('selectionchange', function() {
                    saveSelection();
                    updateFormattingState();
                });
                
                // Listen for click events to update formatting state
                document.addEventListener('click', function() {
                    setTimeout(updateFormattingState, 50);
                });
                
                // Listen for keyup to update formatting state
                document.addEventListener('keyup', function() {
                    updateFormattingState();
                });
                
                let isInserting = false;
                
                function applyFormatting(format) {
                    console.log('🎯 Applying formatting:', format);
                    
                    // Make sure the body is focused and editable
                    document.body.focus();
                    document.body.contentEditable = 'true';
                    
                    const selection = window.getSelection();
                    if (!selection || selection.rangeCount === 0) {
                        console.log('❌ No selection found for formatting');
                        return false;
                    }
                    
                    const selectedText = selection.toString();
                    if (selectedText.length === 0) {
                        console.log('❌ No text selected for formatting');
                        return false;
                    }
                    
                    console.log('📝 Selected text:', selectedText);
                    
                    // Get the range before any operations
                    const range = selection.getRangeAt(0);
                    const originalRange = range.cloneRange();
                    
                    try {
                        // Method 1: Try execCommand first
                        const success = document.execCommand(format, false, null);
                        console.log('⚡ execCommand result for ' + format + ':', success);
                        
                        // Check if formatting was actually applied by looking at the HTML
                        const afterExecHTML = document.body.innerHTML;
                        console.log('📄 HTML after execCommand:', afterExecHTML.substring(0, 200) + '...');
                        
                        if (success) {
                            // Force a DOM refresh to ensure formatting is applied
                            setTimeout(() => {
                                forceRefresh();
                                notifyContentChange();
                                updateFormattingState();
                            }, 10);
                            console.log('✅ execCommand formatting applied successfully');
                            return true;
                        }
                        
                        // Method 2: Manual formatting if execCommand failed
                        console.log('🔧 Trying manual formatting...');
                        
                        // Restore original selection
                        selection.removeAllRanges();
                        selection.addRange(originalRange);
                        
                        const contents = range.extractContents();
                        
                        let wrapper;
                        switch(format) {
                            case 'bold':
                                wrapper = document.createElement('strong');
                                break;
                            case 'italic':
                                wrapper = document.createElement('em');
                                break;
                            case 'underline':
                                wrapper = document.createElement('u');
                                break;
                            default:
                                // Put contents back if unsupported format
                                range.insertNode(contents);
                                return false;
                        }
                        
                        wrapper.appendChild(contents);
                        range.insertNode(wrapper);
                        
                        // Select the newly formatted content
                        const newRange = document.createRange();
                        newRange.selectNodeContents(wrapper);
                        selection.removeAllRanges();
                        selection.addRange(newRange);
                        
                        const afterManualHTML = document.body.innerHTML;
                        console.log('📄 HTML after manual formatting:', afterManualHTML.substring(0, 200) + '...');
                        
                        // Force a DOM refresh to ensure formatting is visible
                        setTimeout(() => {
                            forceRefresh();
                            notifyContentChange();
                            updateFormattingState();
                        }, 10);
                        console.log('✅ Manual formatting applied successfully');
                        return true;
                        
                    } catch (error) {
                        console.error('❌ Error in formatting:', error);
                        // Try to restore original selection on error
                        try {
                            selection.removeAllRanges();
                            selection.addRange(originalRange);
                        } catch (restoreError) {
                            console.error('❌ Could not restore selection:', restoreError);
                        }
                        return false;
                    }
                }
                
                function setFontSize(size) {
                    console.log('Setting font size to:', size);
                    
                    const selection = window.getSelection();
                    if (selection && selection.rangeCount > 0 && selection.toString().length > 0) {
                        // Save the original range
                        const originalRange = selection.getRangeAt(0).cloneRange();
                        const selectedText = selection.toString();
                        
                        console.log('Applying font size to selected text:', selectedText);
                        
                        // Apply to selected text using CSS styles
                        const span = document.createElement('span');
                        span.style.fontSize = size + 'px';
                        
                        try {
                            originalRange.surroundContents(span);
                            
                            // Keep the text selected after formatting
                            setTimeout(function() {
                                const newRange = document.createRange();
                                newRange.selectNodeContents(span);
                                selection.removeAllRanges();
                                selection.addRange(newRange);
                                
                                // Maintain focus
                                document.body.focus();
                                console.log('Font size applied and selection maintained');
                            }, 10);
                            
                        } catch (e) {
                            console.log('Font size surroundContents failed:', e);
                            // Alternative method
                            const contents = originalRange.extractContents();
                            span.appendChild(contents);
                            originalRange.insertNode(span);
                            
                            // Select the new span content
                            setTimeout(function() {
                                const newRange = document.createRange();
                                newRange.selectNodeContents(span);
                                selection.removeAllRanges();
                                selection.addRange(newRange);
                                document.body.focus();
                            }, 10);
                        }
                        
                    } else {
                        // Apply to cursor position or entire body if no selection
                        document.body.style.fontSize = size + 'px';
                        console.log('Font size applied to body (no selection)');
                    }
                    
                    console.log('Font size applied successfully');
                    notifyContentChange();
                    updateFormattingState();
                }
                
                function setTextColor(color) {
                    console.log('Setting text color to:', color);
                    
                    const selection = window.getSelection();
                    if (!selection || selection.rangeCount === 0 || selection.toString().length === 0) {
                        console.log('No text selected for color change');
                        return;
                    }
                    
                    // Save current selection
                    const range = selection.getRangeAt(0);
                    const selectedText = selection.toString();
                    
                    console.log('Applying color to selected text:', selectedText);
                    
                    // Apply color using execCommand
                    document.execCommand('foreColor', false, color);
                    
                    // Restore selection after formatting
                    setTimeout(function() {
                        try {
                            selection.removeAllRanges();
                            selection.addRange(range);
                            document.body.focus();
                            console.log('Text color applied and selection maintained');
                        } catch (e) {
                            console.log('Could not restore selection after color change:', e);
                            document.body.focus();
                        }
                        
                        updateFormattingState();
                    }, 10);
                }
                
                function insertHTML(html) {
                    // Prevent duplicate inserts
                    if (isInserting) {
                        console.log('Insert already in progress, ignoring duplicate');
                        return;
                    }
                    
                    isInserting = true;
                    console.log('Inserting HTML:', html);
                    
                    // Use execCommand to insert at cursor position
                    document.execCommand('insertHTML', false, html);
                    
                    // Reset flag after insert
                    setTimeout(() => { 
                        isInserting = false;
                        console.log('Insert completed');
                    }, 200);
                }
                
                function getSelectionRange() {
                    const selection = window.getSelection();
                    if (selection.rangeCount > 0) {
                        return selection.getRangeAt(0);
                    }
                    return null;
                }
                
                // Test function to verify JavaScript is loaded
                function testFunction() {
                    console.log('JavaScript functions are loaded and ready');
                    return 'ready';
                }
            </script>
        </head>
        <body contenteditable="true" spellcheck="false" style="outline: none; -webkit-user-select: text;">
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Methods to call JavaScript formatting functions
    func applyBold(_ webView: WKWebView) {
        webView.evaluateJavaScript("applyFormatting('bold')")
    }
    
    func applyItalic(_ webView: WKWebView) {
        webView.evaluateJavaScript("applyFormatting('italic')")
    }
    
    func applyUnderline(_ webView: WKWebView) {
        webView.evaluateJavaScript("applyFormatting('underline')")
    }
    
    func applyFontSize(_ webView: WKWebView, size: CGFloat) {
        webView.evaluateJavaScript("setFontSize(\(Int(size)))")
    }
    
    func applyTextColor(_ webView: WKWebView, color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hexColor = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        webView.evaluateJavaScript("setTextColor('\(hexColor)')")
    }
    
    private func loadContent(_ webView: WKWebView) {
        print("📝 RichTextEditor loading content: \(htmlContent)")
        let escapedContent = htmlContent.replacingOccurrences(of: "'", with: "\\'")
                                      .replacingOccurrences(of: "\n", with: "\\n")
                                      .replacingOccurrences(of: "\r", with: "\\r")
        let jsCode = "document.body.innerHTML = '\(escapedContent)'"
        print("📝 JavaScript code: \(jsCode)")
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ Error loading content: \(error)")
            } else {
                print("✅ Content loaded successfully")
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: RichTextEditor
        var hasLoadedInitialContent = false
        var lastKnownContent = ""
        var lastContent = ""
        var isUserTyping = false
        var isWebViewLoaded = false
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "contentChange":
                if let content = message.body as? String {
                    // Store content locally
                    lastKnownContent = content
                    isUserTyping = true
                    
                    // CRITICAL: Only call the callback, DON'T update the binding
                    // Updating binding causes view re-render and keyboard dismiss
                    DispatchQueue.main.async {
                        self.parent.onContentChange(content)
                    }
                    
                    // Reset typing flag after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isUserTyping = false
                    }
                }
            case "tableInsert":
                DispatchQueue.main.async {
                    self.parent.onTableInsert()
                }
            case "formattingState":
                if let stateString = message.body as? String,
                   let data = stateString.data(using: .utf8),
                   let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Update font size if changed
                    if let fontSizeValue = state["fontSize"] as? Int {
                        let fontSize = CGFloat(fontSizeValue)
                        DispatchQueue.main.async {
                            self.parent.onFontSizeDetected(fontSize)
                        }
                    }
                }
            default:
                print("Unknown message: \(message.name)")
            }
        }
        
        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isWebViewLoaded = true
            print("✅ WebView finished loading")
            
            // If we have content to load, do it now
            if !parent.htmlContent.isEmpty && lastContent != parent.htmlContent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.parent.loadContent(webView)
                    self.lastContent = self.parent.htmlContent
                }
            }
        }
    }
}
