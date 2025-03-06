// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Engine
import Foundation
import MetalKit

public enum EngineTools {
    case select
    case control
    case add

    public func toString() -> String {
        switch self {
        case .select:
            return "Select"
        case .control:
            return "Control"
        case .add:
            return "Add"
        }
    }
}

@MainActor
public class ToolManager {
    private var tools: [EngineTools: ToolInterfaceProtocol] = [:]
    private var activeTool: EngineTools?

    public init() {
        setupDefaultTools()
        // Set control as the default tool
        selectTool(.control)
    }

    private func setupDefaultTools() {
        // Initialize the tools we have implementations for
        let selectionTool = SelectionTool()
        tools[.select] = selectionTool

        // Create a basic implementation for the control tool
        tools[.control] = BasicTool(name: "Control Tool")
    }

    public func selectTool(_ toolType: EngineTools) {
        if toolType != activeTool {
            if let currentTool = activeTool, var tool = tools[currentTool] {
                tool.onDeselected()
                tools[currentTool] = tool  // Save the updated state back to the dictionary
            }

            if var newTool = tools[toolType] {
                activeTool = toolType
                newTool.onSelected()
                tools[toolType] = newTool  // Save the updated state back to the dictionary
                Log.info("Tool switched to: \(toolType.toString())")
            } else {
                Log.warning("Tool \(toolType.toString()) not found, creating basic implementation")
                // Create a default implementation for the tool
                var defaultTool = BasicTool(name: toolType.toString())
                defaultTool.onSelected()
                tools[toolType] = defaultTool
                activeTool = toolType
            }
        } else {
            Log.info("Tool \(toolType.toString()) is already active")
        }
    }

    public func getActiveTool() -> EngineTools? {
        return activeTool
    }

    public func updateActiveTool() {
        if let activeTool = activeTool, let tool = tools[activeTool] {
            tool.onUpdate()
        }
    }

    public func registerTool(_ tool: ToolInterfaceProtocol, forType toolType: EngineTools) {
        tools[toolType] = tool
    }

    public func getTool(_ toolType: EngineTools) -> ToolInterfaceProtocol? {
        return tools[toolType]
    }

    // Check if a specific tool type is active
    public func isToolActive(_ toolType: EngineTools) -> Bool {
        return activeTool == toolType
    }
}

// Basic tool implementation that conforms to ToolInterfaceProtocol
// Using struct so we can use the default mutating implementations
@MainActor
struct BasicTool: ToolInterfaceProtocol {
    func onDeselected() {
    }
    
    func onSelected() {
    }
    
    public var isActive: Bool = false
    private let toolName: String

    init(name: String) {
        self.toolName = name
    }

    func onUpdate() {
        // Default implementation does nothing
    }
}

