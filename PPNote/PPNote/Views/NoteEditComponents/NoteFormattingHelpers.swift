import SwiftUI

// Helper functions for note formatting and content manipulation
struct NoteFormattingHelpers {
    // Insert HTML content functions
    static func insertImage(imageData: Data, fileName: String) -> String {
        // Convert image to base64 for HTML embedding
        let base64String = imageData.base64EncodedString()
        return "<img src=\"data:image/png;base64,\(base64String)\" alt=\"\(fileName)\" style=\"max-width: 100%; height: auto;\">"
    }
    
    static func insertTableHTML(tableHTML: String) -> String {
        return tableHTML
    }
    
    static func insertListHTML() -> String {
        return "<ul><li>Mục 1</li><li>Mục 2</li><li>Mục 3</li></ul>"
    }
    
    static func insertQuoteHTML() -> String {
        return "<blockquote>Trích dẫn của bạn</blockquote>"
    }
    
    static func insertDividerHTML() -> String {
        return "<hr>"
    }
    
    static func insertDateHTML() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "vi_VN")
        return "<p>📅 \(formatter.string(from: Date()))</p>"
    }
    
    static func insertTimeHTML() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "<p>⏰ \(formatter.string(from: Date()))</p>"
    }
    
    // Math calculation helpers
    static func calculateExpression(_ expression: String) -> Double? {
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
    
    static func formatResult(_ result: Double) -> String {
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(result))
        } else {
            return String(format: "%.2f", result).replacingOccurrences(of: ".00", with: "")
        }
    }
}