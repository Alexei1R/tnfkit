import SwiftUI
import UIKit

struct LayersView: View {
    @ObservedObject var toolSelector: ToolSelector
    @Binding var rightPanelWidth: CGFloat
    var geometry: GeometryProxy
    
    // Compute panel title based on current mode
    private var panelTitle: String {
        switch toolSelector.currentMode {
        case .object:
            return "Objects"
        case .vertex:
            return "Vertices"
        case .animate:
            return "Animation"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text(panelTitle)
                    .foregroundColor(.white)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        toolSelector.showLayers.toggle()
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Mode-specific content
            Group {
                switch toolSelector.currentMode {
                case .object:
                    ObjectLayerView()
                case .vertex:
                    VStack{
                        Text("Vertex")
                    }
                case .animate:
                    VStack{
                        Text("Animate")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.opacity(0.85))
        .cornerRadius(12, corners: [UIRectCorner.topLeft, UIRectCorner.bottomLeft])
        .overlay(
            HStack(spacing: 0) {
                // Resize handle
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = rightPanelWidth - value.translation.width
                                rightPanelWidth = max(180, min(newWidth, geometry.size.width * 0.35))
                            }
                    )
                Spacer()
            },
            alignment: .leading
        )
    }
}

// Helper for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
