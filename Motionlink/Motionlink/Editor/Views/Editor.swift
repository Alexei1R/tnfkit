import SwiftUI
import tnfkit

struct EditorView: View {
    // Engine interface
    @State private var engine: TNFEngine?

    // UI elements
    @StateObject var toolSelector = ToolSelector()
    @State private var rightPanelWidth: CGFloat = 0
    
    let layersWidthPercentage: ClosedRange<CGFloat> = 0.33...0.50

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
                            // NOTE: Debug button at the top
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
                            toolSelector: toolSelector,
                            rightPanelWidth: $rightPanelWidth,
                            geometry: geometry,
                            widthPercentageRange: layersWidthPercentage
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
            .onAppear {
                rightPanelWidth = geometry.size.width * layersWidthPercentage.upperBound
            }
            .onChange(of: geometry.size) { newSize in
                if toolSelector.showLayers {
                    rightPanelWidth = newSize.width * layersWidthPercentage.upperBound
                }
            }
        }
        .ignoresSafeArea()
        .task {
            if engine == nil {
                engine = TNFEngine()
                
                // Set up tool selection handler in the Editor
                toolSelector.setupToolSelectionHandler { [weak engine] engineTool in
                    guard let engine = engine else { return }
                    // Must use Task because TNFEngine methods are @MainActor isolated
                    Task { @MainActor in
                        engine.selectionToolCallback(toolType: engineTool)
                    }
                }
            }
        }
    }
}
