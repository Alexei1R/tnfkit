// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import SwiftUI
import UIKit

struct LayersView: View {
    @ObservedObject var toolSelector: ToolSelector
    @Binding var rightPanelWidth: CGFloat
    var geometry: GeometryProxy
    var widthPercentageRange: ClosedRange<CGFloat>

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text(toolSelector.currentMode.title)
                    .foregroundColor(.white)
                    .font(.headline)

                Spacer()

                Button(action: {
                    withAnimation {
                        toolSelector.toggleLayers()
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Mode-specific content using the createView method
            toolSelector.currentMode.createView()
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
                                // Calculate min and max widths based on screen size and percentages
                                let minWidth = geometry.size.width * widthPercentageRange.lowerBound
                                let maxWidth = geometry.size.width * widthPercentageRange.upperBound
                                rightPanelWidth = max(minWidth, min(newWidth, maxWidth))
                            }
                    )
                Spacer()
            },
            alignment: .leading
        )
    }
}

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
