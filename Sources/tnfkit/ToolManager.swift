// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

public enum EngineTools {
    case none
    case select
    case control
    case add

    public func toString() -> String {
        switch self {
        case .none:
            return "none"
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
        selectTool(.control)
    }

    private func setupDefaultTools() {
        let selectionTool = SelectionTool()
        tools[.select] = selectionTool

        tools[.control] = BasicTool(name: "Control Tool")
    }

    public func selectTool(_ toolType: EngineTools) {
        if toolType != activeTool {
            if let currentTool = activeTool, var tool = tools[currentTool] {
                tool.onDeselected()
                tools[currentTool] = tool
            }

            if var newTool = tools[toolType] {
                activeTool = toolType
                newTool.onSelected()
                tools[toolType] = newTool
                Log.info("Tool switched to: \(toolType.toString())")
            } else {
                Log.warning("Tool \(toolType.toString()) not found, creating basic implementation")
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

    public func isToolActive(_ toolType: EngineTools) -> Bool {
        return activeTool == toolType
    }
}

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
    }
}
