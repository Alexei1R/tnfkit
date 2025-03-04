//
//  ToolsPanelView.swift
//  Motionlink
//
//  Created by rusu alexei on 04.03.2025.
//

import SwiftUI

struct ToolsPanelView: View {
    @ObservedObject var toolSelector: ToolSelector

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    ForEach(toolSelector.tools) { tool in
                        ToolButton(
                            icon: tool.icon,
                            isSelected: toolSelector.selectedTool?.id == tool.id,
                            size: 30
                        ) {
                            toolSelector.selectedTool = tool
                        }
                    }
                }
            }
            Spacer()

            Button(action: {
                withAnimation {
                    toolSelector.showLayers.toggle()
                }
            }) {
                Image(systemName: "sidebar.left")
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical)
        .padding(.horizontal, 8)
    }
}

struct QuickButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
        }
    }
}

struct ToolButton: View {
    let icon: String
    let isSelected: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? .blue : .white)
                .frame(width: size, height: size)
                .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
                .cornerRadius(8)
        }
    }
}
