//
//  ContentView.swift
//  Motionlink
//
//  Created by rusu alexei on 03.03.2025.
//

import SwiftUI
import tnfkit

struct EditorView: View {
    
    //NOTE: Engine interface
    @State private var engine: TNFEngine?
    
    //NOTE: UI elements
    @StateObject var toolSelector = ToolSelector()
    
    var body: some View {
        HStack {
            
            ToolsPanelView(toolSelector: toolSelector).background(Color.blue.opacity(0.05))
            
            if let engine = engine {
                engine.createViewport().ignoresSafeArea()
            } else {
                Text("Initializing Metal engine...")
            }
            
        }
        .ignoresSafeArea()
        .padding(.leading, 12)
        .task {
            if engine == nil {
                engine = TNFEngine()
                
                // Make sure to sync initial tool state once engine is ready
                if let tool = toolSelector.selectedTool, let safeEngine = engine {
                    syncToolWithEngine(tool: tool, engine: safeEngine)
                }
            }
        }.onAppear {
            setupToolCallback()
            setupLayersCallback()
        }.ignoresSafeArea()
    }
    
    private func setupToolCallback() {
        // Remove [weak self] since EditorView is a struct (value type)
        toolSelector.onToolSelection { selectedTool in
            guard let tool = selectedTool, let engine = engine else { return }
            syncToolWithEngine(tool: tool, engine: engine)
        }
    }
    
    private func syncToolWithEngine(tool: Tool, engine: TNFEngine) {
        switch tool.name {
        case "Select":
            engine.selectionToolCallback(toolType: .select)
        case "Control":
            engine.selectionToolCallback(toolType: .control)
        case "Add":
            engine.selectionToolCallback(toolType: .add)
        default:
            print("Unknown tool name: \(tool.name)")
        }
    }
    
    private func setupLayersCallback() {
        toolSelector.onLayersVisibilityChange { isVisible in
            print("Layers visibility changed: \(isVisible)")
        }
    }
}
