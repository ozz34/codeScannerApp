//
//  codeScannerAppApp.swift
//  codeScannerApp
//
//  Created by Иван Худяков on 24.10.2025.
//

import SwiftUI

@main
struct codeScannerAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
