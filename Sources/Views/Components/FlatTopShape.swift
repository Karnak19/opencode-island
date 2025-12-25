import SwiftUI

/// Custom shape with a flat top and rounded bottom corners
/// Designed to integrate with the MacBook notch
struct FlatTopShape: Shape {
    var bottomRadius: CGFloat
    
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let br = min(bottomRadius, w / 2, h / 2)
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addQuadCurve(to: CGPoint(x: w - br, y: h), control: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: br, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h - br), control: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        
        return path
    }
}
