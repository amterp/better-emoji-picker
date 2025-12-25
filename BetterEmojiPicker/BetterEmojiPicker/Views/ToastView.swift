//
//  ToastView.swift
//  BetterEmojiPicker
//
//  A simple toast overlay for brief feedback messages (e.g., "Copied!").
//

import SwiftUI

/// A brief toast notification that appears centered in its container.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.75))
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ToastView(message: "Copied!")
        .padding(50)
}
