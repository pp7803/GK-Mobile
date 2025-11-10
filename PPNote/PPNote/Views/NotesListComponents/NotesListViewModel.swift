import SwiftUI
import Combine

class NotesListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var refreshTrigger = false

    private var cancellables = Set<AnyCancellable>()
    private var notificationObserver: NSObjectProtocol?

    init() {
        setupNotificationObservers()
    }

    deinit {
        cleanup()
    }

    private func setupNotificationObservers() {
        // Use a safer notification observer that checks if self still exists
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NotesUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Add a small delay to ensure view updates are complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.refreshTrigger.toggle()
            }
        }
    }

    func cleanup() {
        cancellables.removeAll()
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }
}