//
//  PPNoteApp.swift
//  PPNote
//
//  Created by Phát Phạm on 22/10/25.
//

import SwiftUI
import UserNotifications

@main
struct PPNoteApp: App {
    let coreDataManager = CoreDataManager.shared
    
    init() {
        // Request notification permission
        requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.context)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
