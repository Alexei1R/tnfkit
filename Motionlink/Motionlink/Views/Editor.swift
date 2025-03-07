import SwiftUI
import tnfkit

struct EditorView: View {
    // Engine interface
    @State private var engine: TNFEngine?
    
    // UI elements
    @StateObject var toolSelector = ToolSelector()
    @State private var leftPanelWidth: CGFloat = 60
    @State private var rightPanelWidth: CGFloat = 180
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content area with viewport and layers in HStack
                HStack(spacing: 0) {
                    
                    ZStack {
                        // Engine viewport area
                        if let engine = engine {
                            engine.createViewport().ignoresSafeArea()
                        } else {
                            Text("Initializing Metal engine...")
                        }
                        
                        
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ModeSelectorView(toolSelector: toolSelector)
                                    .padding(.bottom, 24)
                                    .padding(.trailing, 24)
                            }
                        }
                    }
                    
                    
                    // Layers panel (if visible)
                    if toolSelector.showLayers {
                        LayersView(toolSelector: toolSelector, rightPanelWidth: $rightPanelWidth, geometry: geometry)
                            .frame(width: rightPanelWidth, height: geometry.size.height)
                            .transition(.move(edge: .trailing))
                    }
                }
                
                // Tools panel overlay
                HStack() {
                    ToolsPanelView(toolSelector: toolSelector)
                        .frame(height: geometry.size.height * 0.75)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                                .shadow(color: Color.black.opacity(0.2), radius: 10)
                        )
                        .padding(.leading, 20)
                    
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                
            }
        }
        .ignoresSafeArea()
        .task {
            if engine == nil {
                engine = TNFEngine()
                
                // Make sure to sync initial tool state once engine is ready
                if let tool = toolSelector.selectedTool, let safeEngine = engine {
                    syncToolWithEngine(tool: tool, engine: safeEngine)
                }
            }
        }
        .onAppear {
            setupToolCallback()
            setupLayersCallback()
            setupModeCallback()
        }
    }
    
    private func setupToolCallback() {
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
    
    private func setupModeCallback() {
        toolSelector.onModeChange { mode in
            print("Mode changed to: \(mode.rawValue)")
        }
    }
}
