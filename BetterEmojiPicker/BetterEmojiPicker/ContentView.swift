//
//  ContentView.swift
//  BetterEmojiPicker
//
//  Note: This file is not used by the app. BEP is a menu bar app
//  that uses FloatingPanel for its UI, not a WindowGroup.
//
//  This file is kept for Xcode preview purposes only.
//

import SwiftUI

/// Placeholder view - not used in the actual app.
/// The app's UI is in PickerView, shown in a FloatingPanel.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "face.smiling")
                .imageScale(.large)
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Better Emoji Picker")
                .font(.title)

            Text("This is a menu bar app.")
                .foregroundColor(.secondary)

            Text("Look for 😊 in your menu bar!")
                .font(.caption)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

#Preview {
    ContentView()
}
