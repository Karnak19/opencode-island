import SwiftUI

/// Collapsed pill view shown in the notch when sessions have active work
struct CollapsedPillView: View {
    let sessions: [IslandState.Session]
    
    var body: some View {
        HStack(spacing: 0) {
            leadingIcon
            
            Spacer()
            
            trailingIcon
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Subviews
    
    private var leadingIcon: some View {
        Image(systemName: "apple.terminal.fill")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(Theme.Colors.accent)
            .frame(width: Theme.Dimensions.iconFrameSize, height: Theme.Dimensions.collapsedSize.height)
    }
    
    @ViewBuilder
    private var trailingIcon: some View {
        if let waiting = waitingSession {
            Image(systemName: PermissionType.icon(for: waiting.permissionType))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.yellow)
                .frame(width: Theme.Dimensions.iconFrameSize, height: Theme.Dimensions.collapsedSize.height)
        } else if processingSession != nil {
            SpinnerView()
                .frame(width: Theme.Dimensions.iconFrameSize, height: Theme.Dimensions.collapsedSize.height)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.statusIdle)
                .frame(width: Theme.Dimensions.iconFrameSize, height: Theme.Dimensions.collapsedSize.height)
        }
    }
    
    // MARK: - Helpers
    
    private var waitingSession: IslandState.Session? {
        sessions.first { $0.status == .waiting }
    }
    
    private var processingSession: IslandState.Session? {
        sessions.first { $0.status == .processing }
    }
}
