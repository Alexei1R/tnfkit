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
            }
        }.onAppear {
            setupToolCallback()
            setupLayersCallback()
        }
        
    }
    
    private func setupToolCallback() {
        
        
        toolSelector.onToolSelection { selectedTool in
            guard let tool = selectedTool else { return }
            
            switch tool.name {
            case "Select":
                engine!.selectionToolCallback(toolType:  .select)
            case "Control":
                engine!.selectionToolCallback(toolType: .control)
            case "Add":
                engine!.selectionToolCallback(toolType: .add)
            default:
                print("Unknown tool name: \(tool.name)")
            }
        }
    }
    
    
    private func setupLayersCallback() {
        toolSelector.onLayersVisibilityChange { isVisible in
            print("Layers visibility changed: \(isVisible)")
            
        }
    }
    
}
