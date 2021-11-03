//
//  ContentView.swift
//  EmojiArt
//
//  Created by Volodymyr Seredovych on 27.10.2021.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    var body: some View {
        content()
        HStack {
            palette
            deleteButton(buttonText: (selectedEmojis.count <= 1) ?
                   "Delete Emoji" :
                   "Delete \(selectedEmojis.count) Emojis")
            .disabled(selectedEmojis.isEmpty)
        }
    }
    
    var palette: some View {
        ScrollingEmojisView(emojis: Constants.testEmojis)
            .font(.system(size: Constants.defaultEmojiSize))
    }
    
    private func deleteButton(buttonText: String) -> some View {
        return Button(buttonText) {
            for emoji in selectedEmojis {
                document.deleteEmoji(emoji)
            }
            selectedEmojis.removeAll()
        }
        .padding()
        .foregroundColor(Color.white)
        .background(Color.accentColor)
    }
    
    private func content() -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay {
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                } .gesture(doubleTapToZoom(in: geometry.size))
                ForEach(document.emojis) { emoji in
                    Text(emoji.text)
                        .border(Color.blue, width: selectedEmojis.contains(matching: emoji) ? 2 : 0)
                        .font(animatableWithSize: self.scale(for: emoji))
                        .position(position(for: emoji, in: geometry.size))
                        .zIndex(selectedEmojis.contains(matching: emoji) ? 1 : 0)
                        .gesture(tapToSelect(emoji: emoji))
                        .gesture(panEmojiGesture(emoji: emoji))
                }
            }
            .gesture(panGesture()
                .simultaneously(with: zoomGesture()
                .simultaneously(with: tapToDeselect())))
            .onDrop(of: ["public.image","public.text"], isTargeted: nil) { providers, location in
                var location = CGPoint(x: location.x, y: geometry.convert(location, from: .global).y)
                location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                location = CGPoint(x: location.x - self.panOffset.width, y: location.y - self.panOffset.height)
                location = CGPoint(x: location.x / self.zoomScale, y: location.y / self.zoomScale)
                return self.drop(providers: providers, at: location)
            }
        }
    }
    
    // MARK: - Select Emoji
    
    @State private var selectedEmojis: Set<EmojiArt.Emoji> = []
    
    private func tapToSelect(emoji: EmojiArt.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                selectedEmojis.toggleMatching(value: emoji)
            }
    }
    
    private func tapToDeselect() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                self.selectedEmojis.removeAll()
            }
    }
    
    // MARK: - Zoom Gesture
    
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScaleEmoji: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        if selectedEmojis.isEmpty {
            return MagnificationGesture()
                .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                    gestureZoomScale = latestGestureScale
                }
                .onEnded { finalGestureScale in
                    steadyStateZoomScale *= finalGestureScale
                }
        } else {
            return MagnificationGesture()
                .updating($gestureZoomScaleEmoji) { latestGestureScale, gestureZoomScaleEmoji, transaction in
                    gestureZoomScaleEmoji = latestGestureScale
                }
                .onEnded { finalGestureScale in
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                }
        }
    }
    
    // MARK: - Pan Gesture
    
    @State private var steadyStatePanOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        return (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
            }
            .onEnded { finalDragGestureValue in
                self.steadyStatePanOffset = self.steadyStatePanOffset + (finalDragGestureValue.translation / self.zoomScale)
            }
    }
    
    // MARK: - Emoji Pan Gesture
    
    @GestureState private var gesturePanOffsetEmoji: CGSize = .zero
    
    private func panEmojiGesture(emoji: EmojiArt.Emoji) -> some Gesture {
        DragGesture()
            .onChanged() { _ in
                singleEmoji = selectedEmojis.contains(matching: emoji) ? nil : emoji
            }
            .updating($gesturePanOffsetEmoji) { latestDragGestureValue, gesturePanOffsetEmoji, transaction in
                if selectedEmojis.contains(matching: emoji) {
                    gesturePanOffsetEmoji = latestDragGestureValue.translation
                } else {
                    gesturePanOffsetEmoji = latestDragGestureValue.translation
                }
            }
            .onEnded { finalDragGestureValue in
                if selectedEmojis.contains(matching: emoji) {
                    for e in selectedEmojis {
                        document.moveEmoji(e, by: finalDragGestureValue.translation / self.zoomScale)
                    }
                } else {
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / self.zoomScale)
                    singleEmoji = nil
                }
            }
    }
    
    @State private var singleEmoji: EmojiArt.Emoji?
    
    private var singleEmojiText: String {
        get {
            if let emoji = singleEmoji {
                return emoji.text
            } else {
                return "nil"
            }
        }
    }
    
    // MARK: - Zoom to Fit Gesture (Background)
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    self.zoomToFit(self.document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0 {
            let hZoom = (size.width - 32) / image.size.width
            let vZoom = (size.height - 32) / image.size.height
            self.steadyStatePanOffset = .zero
            self.steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Emoji Supporting Funcs
    
    private func scale(for emoji: EmojiArt.Emoji) -> CGFloat {
        if selectedEmojis.contains(matching: emoji){
            return emoji.fontSize * self.zoomScale * self.gestureZoomScaleEmoji
        } else {
            return emoji.fontSize * self.zoomScale
        }
    }
    
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        if let e = singleEmoji {
            if e.id == emoji.id {
                location = CGPoint(x: location.x + gesturePanOffsetEmoji.width, y: location.y + gesturePanOffsetEmoji.height)
            }
        } else {
            if selectedEmojis.contains(matching: emoji) {
                location = CGPoint(x: location.x + gesturePanOffsetEmoji.width, y: location.y + gesturePanOffsetEmoji.height)
            }
        }
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            self.document.setBackgroundURL(url)
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                self.document.addEmoji(string, at: (x: Int(location.x), y: Int(location.y)), size: Constants.defaultEmojiSize)
            }
        }
        return found
    }
    
    struct Constants {
        static let testEmojis: String = "⚽️🏀🏈⚾️🎾🏐🏉🎱🏓🏸🪃⛳️🪁🏹🥊🥋🛹🛼🥌"
        static let defaultEmojiSize: CGFloat = 40
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
