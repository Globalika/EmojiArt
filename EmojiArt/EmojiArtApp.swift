//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Volodymyr Seredovych on 27.10.2021.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    let document = EmojiArtDocument()
    let paletteStore = PaletteStore(named: "Default")
    
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: document)
        }
    }
}
