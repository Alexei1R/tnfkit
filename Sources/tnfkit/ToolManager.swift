// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Engine
import Foundation

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
    }

    private func setupDefaultTools() {
        let selectionTool = SelectionTool()
        tools[.select] = selectionTool
    }

    public func selectTool(_ toolType: EngineTools) {
        if toolType != activeTool {
            if let currentTool = activeTool, let tool = tools[currentTool] {
                tool.onDeselected()
            }

            if let newTool = tools[toolType] {
                activeTool = toolType
                newTool.onSelected()
            } else {
                print("Warning: Tool \(toolType.toString()) not found")
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
}
