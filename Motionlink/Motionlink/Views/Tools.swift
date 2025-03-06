//
//  Tools.swift
//  Motionlink
//
//  Created by rusu alexei on 04.03.2025.
//

import Foundation
import SwiftUI

struct Tool: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let group: ToolGroup
}

enum ToolGroup {
    case selection, manipulation, creation
}

class ToolSelector: ObservableObject {
    typealias ToolSelectionCallback = (Tool?) -> Void
    typealias LayersVisibilityCallback = (Bool) -> Void
    
    private var toolSelectionCallbacks: [ToolSelectionCallback] = []
    private var layersVisibilityCallbacks: [LayersVisibilityCallback] = []

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

    let tools: [Tool] = [
        //Selection tool draw the area to select
        Tool(
            name: "Select", icon: "scribble.variable",
            group: .selection),

        Tool(name: "Control", icon: "move.3d", group: .manipulation),
        Tool(name: "Add", icon: "cube", group: .creation),

    ]
    
    init() {
        // Set "Control" as the default tool
        selectedTool = tools.first { $0.name == "Control" }
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

    func removeToolSelectionCallback(_ callback: @escaping ToolSelectionCallback) {
        toolSelectionCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    func removeLayersVisibilityCallback(_ callback: @escaping LayersVisibilityCallback) {
        layersVisibilityCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
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
}
