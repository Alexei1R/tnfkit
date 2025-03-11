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
                HStack(spacing: 0) {
                    ZStack {
                        // NOTE: Engine viewport area
                        if let engine = engine {
                            engine.createViewport().ignoresSafeArea()
                        } else {
                            Text("Initializing Metal engine...")
                        }

                        VStack {
                            // Debug button at the top
                            HStack {
                                Spacer()
                                Button(action: {
                                    guard let engine = engine else { return }
                                    engine.debugButton()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play")
                                            .font(.system(size: 16, weight: .medium))
                                        Text("Debug")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.7))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(16)
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            Spacer()
                            
                            // Mode selector at the bottom
                            HStack {
                                Spacer()
                                ModeSelectorView(toolSelector: toolSelector)
                                    .padding(.bottom, 24)
                                    .padding(.trailing, 24)
                            }
                        }
                    }

                    if toolSelector.showLayers {
                        LayersView(
                            toolSelector: toolSelector, rightPanelWidth: $rightPanelWidth,
                            geometry: geometry
                        )
                        .frame(width: rightPanelWidth, height: geometry.size.height)
                        .transition(.move(edge: .trailing))
                    }
                }

                HStack {
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
