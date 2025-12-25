import SwiftUI

/// View modifier that creates a pulsing scale/opacity animation
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.5 : 1.0)
            .opacity(isPulsing ? 0 : 1)
            .animation(
                SwiftUI.Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: false),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
