import SwiftUI

/// Expanded content view for the Island
struct ExpandedContentView: View {
    @ObservedObject var state: IslandState
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if state.sessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
            
            Spacer()
            footerBar
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack(spacing: 0) {
            leadingIcon
            
            Spacer()
            
            closeButton
        }
        .padding(.horizontal, 4)
    }
    
    private var leadingIcon: some View {
        Image(systemName: "apple.terminal.fill")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(Theme.Colors.accent)
            .frame(width: Theme.Dimensions.iconFrameSize, height: Theme.Dimensions.collapsedSize.height)
    }
    
    private var closeButton: some View {
        Button(action: {
            withAnimation(Theme.Animation.spring) {
                state.isExpanded = false
            }
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.accent.opacity(0.6))
        }
        .buttonStyle(.plain)
        .frame(width: Theme.Dimensions.iconFrameSize, height: Theme.Dimensions.collapsedSize.height)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "terminal")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(Theme.Colors.accent.opacity(0.3))
            
            Text("No active sessions")
                .font(Theme.Typography.monospacedBody)
                .foregroundColor(.white.opacity(0.4))
            
            Text("Start an OpenCode session\nto monitor activity here")
                .font(Theme.Typography.monospacedCaption)
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var sessionsList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(state.sessions) { session in
                    SessionRowView(session: session)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    private var footerBar: some View {
        HStack {
            Button(action: {
                state.onOpenSettings?()
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Approve actions in terminal")
                .font(Theme.Typography.monospacedTiny)
                .foregroundColor(.white.opacity(0.3))
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit")
                    .font(Theme.Typography.monospacedCaption)
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
