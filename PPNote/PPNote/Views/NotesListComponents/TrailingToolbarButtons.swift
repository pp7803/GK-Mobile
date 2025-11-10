import SwiftUI

struct TrailingToolbarButtons: View {
    @Binding var showingAIPrompt: Bool
    @Binding var showingNewNote: Bool

    var body: some View {
        HStack(spacing: 8) {
            aiButton
            newNoteButton
        }
    }

    private var aiButton: some View {
        Button(action: { showingAIPrompt = true }) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    private var newNoteButton: some View {
        Button(action: { showingNewNote = true }) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}