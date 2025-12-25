import SwiftUI

/// View component for displaying a single session row
struct SessionRowView: View {
    let session: IslandState.Session
    
    var body: some View {
        let isWaiting = session.status == .waiting
        
        return HStack(spacing: 12) {
            statusIndicator(isWaiting: isWaiting)
            
            sessionInfo(isWaiting: isWaiting)
            
            Spacer()
            
            trailingIcon(isWaiting: isWaiting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Dimensions.sessionRowCornerRadius)
                .fill(isWaiting ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Dimensions.sessionRowCornerRadius)
                        .strokeBorder(isWaiting ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Subviews
    
    private func statusIndicator(isWaiting: Bool) -> some View {
        ZStack {
            if isWaiting {
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .modifier(PulseAnimation())
            }
            Circle()
                .fill(statusColor(for: session.status))
                .frame(width: 8, height: 8)
        }
        .frame(width: 16, height: 16)
    }
    
    private func sessionInfo(isWaiting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(Theme.Typography.monospacedBody)
                .foregroundColor(.white)
            
            if isWaiting {
                waitingMessage
            } else {
                statusText
            }
        }
    }
    
    private var waitingMessage: some View {
        HStack(spacing: 6) {
            Image(systemName: PermissionType.icon(for: session.permissionType))
                .font(.system(size: 10))
                .foregroundColor(.yellow)
            
            Text(PermissionType.label(for: session.permissionType))
                .font(Theme.Typography.monospacedSmall)
                .foregroundColor(.yellow)
            
            if let tool = session.pendingTool, tool != session.permissionType {
                Text("(\(tool))")
                    .font(Theme.Typography.monospacedTiny)
                    .foregroundColor(.yellow.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
    
    private var statusText: some View {
        Text(session.status.rawValue)
            .font(Theme.Typography.monospacedCaption)
            .foregroundColor(statusColor(for: session.status))
    }
    
    private func trailingIcon(isWaiting: Bool) -> some View {
        Group {
            if isWaiting {
                Image(systemName: PermissionType.icon(for: session.permissionType))
                    .font(.system(size: 16))
                    .foregroundColor(.yellow.opacity(0.8))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func statusColor(for status: IslandState.Session.Status) -> Color {
        switch status {
        case .idle: return Theme.Colors.statusIdle
        case .processing: return Theme.Colors.statusProcessing
        case .waiting: return Theme.Colors.statusWaiting
        }
    }
}
