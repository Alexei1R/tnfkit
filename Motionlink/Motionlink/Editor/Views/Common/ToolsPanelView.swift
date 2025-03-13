// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import SwiftUI

struct ToolsPanelView: View {
    @ObservedObject var toolSelector: ToolSelector
    
    private var toolButtons: some View {
        VStack(spacing: 8) {
            ForEach(toolSelector.availableTools) { tool in
                toolButton(for: tool)
            }
        }
    }
    
    private func toolButton(for tool: Tool) -> some View {
        let isSelected = toolSelector.selectedTool?.id == tool.id
        
        return ToolButton(
            icon: tool.icon,
            isSelected: isSelected,
            size: 35
        ) {
            toolSelector.selectTool(tool)
        }
    }
    
    private var layersToggleButton: some View {
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
    
    var body: some View {
        VStack {
            ScrollView {
                toolButtons
            }
            Spacer()
            layersToggleButton
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
                .cornerRadius(10)
        }
    }
}
