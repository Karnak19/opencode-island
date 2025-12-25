import SwiftUI

/// Rotating spinner icon for processing state
struct SpinnerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "arrow.trianglehead.2.clockwise")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Theme.Colors.accent)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                SwiftUI.Animation.linear(duration: 1.0)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}
