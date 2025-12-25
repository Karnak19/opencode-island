import SwiftUI
import os.log

/// Main Island view that handles the Dynamic Island UI
struct IslandView: View {
    @ObservedObject var state: IslandState
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if state.isExpanded {
                    ExpandedContentView(state: state)
                } else if state.showPending {
                    CollapsedPillView(sessions: state.sessions)
                }
            }
            .frame(width: currentWidth, height: currentHeight)
            .background(
                FlatTopShape(bottomRadius: bottomCornerRadius)
                    .fill(Theme.Colors.background)
                    .shadow(
                        color: .black.opacity(state.showPending || state.isExpanded ? 0.5 : 0),
                        radius: 20,
                        y: 10
                    )
            )
            .clipShape(FlatTopShape(bottomRadius: bottomCornerRadius))
            .animation(Theme.Animation.spring, value: state.isExpanded)
            .animation(Theme.Animation.spring, value: state.showPending)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Computed Properties
    
    private var currentWidth: CGFloat {
        if state.isExpanded { return Theme.Dimensions.expandedSize.width }
        else if state.showPending { return Theme.Dimensions.collapsedSize.width }
        else { return Theme.Dimensions.hiddenSize.width }
    }
    
    private var currentHeight: CGFloat {
        if state.isExpanded { return Theme.Dimensions.expandedSize.height }
        else if state.showPending { return Theme.Dimensions.collapsedSize.height }
        else { return Theme.Dimensions.hiddenSize.height }
    }
    
    private var bottomCornerRadius: CGFloat {
        if state.isExpanded { return Theme.Dimensions.expandedCornerRadius }
        else { return Theme.Dimensions.collapsedCornerRadius }
    }
}
