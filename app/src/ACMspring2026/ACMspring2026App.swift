//
//  ACMspring2026App.swift
//  ACMspring2026
//
//  Created by Ruthvik Penubarthi on 2/5/26.
//

import SwiftUI

@main
struct ACMspring2026App: App {
    @StateObject private var waterStore = WaterStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(waterStore)
        }
    }
}


