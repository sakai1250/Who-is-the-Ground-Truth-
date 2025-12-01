//
//  whereGTApp.swift
//  whereGT
//
//  Created by 坂井泰吾 on 2025/12/02.
//

import SwiftUI
import CoreData

@main
struct whereGTApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
