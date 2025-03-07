import Foundation
import SwiftUI

struct Tool: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let group: ToolGroup
    let supportedModes: [Mode] 
    
    init(name: String, icon: String, group: ToolGroup, supportedModes: [Mode] = Mode.allCases) {
        self.name = name
        self.icon = icon
        self.group = group
        self.supportedModes = supportedModes
    }
}

enum ToolGroup {
    case selection, manipulation, creation
}

class ToolSelector: ObservableObject {
    typealias ToolSelectionCallback = (Tool?) -> Void
    typealias LayersVisibilityCallback = (Bool) -> Void
    typealias ModeChangeCallback = (Mode) -> Void
    
    private var toolSelectionCallbacks: [ToolSelectionCallback] = []
    private var layersVisibilityCallbacks: [LayersVisibilityCallback] = []
    private var modeChangeCallbacks: [ModeChangeCallback] = []
    
    @Published var selectedTool: Tool? {
        didSet {
            notifyToolSelectionCallbacks()
        }
    }
    
    @Published var showLayers: Bool = false {
        didSet {
            notifyLayersVisibilityCallbacks()
        }
    }
    
    @Published var currentMode: Mode = .object {
        didSet {
            // When mode changes, filter available tools and potentially reset selected tool
            if let selectedTool = selectedTool, !selectedTool.supportedModes.contains(currentMode) {
                // If current tool doesn't support new mode, select first available tool
                if let firstAvailableTool = availableTools.first {
                    self.selectedTool = firstAvailableTool
                }
            }
            // Notify mode change callbacks
            notifyModeChangeCallbacks()
        }
    }
    
    // Full list of all tools
    let allTools: [Tool] = [
        // Selection tools
        Tool(
            name: "Select",
            icon: "scribble.variable",
            group: .selection,
            supportedModes: [.object, .vertex]
        ),
        
        // Manipulation tools
        Tool(
            name: "Control",
            icon: "move.3d",
            group: .manipulation,
            supportedModes: [.object]
        ),
        
        // Object mode specific tools
        Tool(
            name: "Add",
            icon: "cube",
            group: .creation,
            supportedModes: [.object]
        ),
        
        // Vertex mode specific tools
        Tool(
            name: "Extrude",
            icon: "arrow.up.and.down.and.arrow.left.and.right",
            group: .manipulation,
            supportedModes: [.vertex]
        ),
        
        // Animation mode specific tools
        Tool(
            name: "Keyframe",
            icon: "diamond",
            group: .creation,
            supportedModes: [.animate]
        ),
        Tool(
            name: "Timeline",
            icon: "timeline.selection",
            group: .manipulation,
            supportedModes: [.animate]
        )
    ]
    
    // Dynamic property that returns only tools for the current mode
    var availableTools: [Tool] {
        return allTools.filter { $0.supportedModes.contains(currentMode) }
    }
    
    init() {
        // Set "Control" as the default tool
        selectedTool = allTools.first { $0.name == "Control" }
    }
    
    func setMode(_ mode: Mode) {
        currentMode = mode
    }
    
    func onToolSelection(_ callback: @escaping ToolSelectionCallback) {
        toolSelectionCallbacks.append(callback)
        // Call the callback immediately with the current selection
        if let selectedTool = selectedTool {
            callback(selectedTool)
        }
    }
    
    func onLayersVisibilityChange(_ callback: @escaping LayersVisibilityCallback) {
        layersVisibilityCallbacks.append(callback)
        // Immediately call the callback with the current state
        callback(showLayers)
    }
    
    func onModeChange(_ callback: @escaping ModeChangeCallback) {
        modeChangeCallbacks.append(callback)
        // Call the callback immediately with the current mode
        callback(currentMode)
    }
    
    func removeToolSelectionCallback(_ callback: @escaping ToolSelectionCallback) {
        toolSelectionCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    func removeLayersVisibilityCallback(_ callback: @escaping LayersVisibilityCallback) {
        layersVisibilityCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    func removeModeChangeCallback(_ callback: @escaping ModeChangeCallback) {
        modeChangeCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    private func notifyToolSelectionCallbacks() {
        toolSelectionCallbacks.forEach { callback in
            callback(selectedTool)
        }
    }
    
    private func notifyLayersVisibilityCallbacks() {
        layersVisibilityCallbacks.forEach { callback in
            callback(showLayers)
        }
    }
    
    private func notifyModeChangeCallbacks() {
        modeChangeCallbacks.forEach { callback in
            callback(currentMode)
        }
    }
}
