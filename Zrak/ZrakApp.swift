//
//  ZrakApp.swift
//  Zrak
//
//  Created by David Mišmaš on 25. 2. 2026.
//

import SwiftUI

@main
struct ZrakApp: App {
    @StateObject private var premiumManager = PremiumManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(premiumManager)
        }
    }
}
