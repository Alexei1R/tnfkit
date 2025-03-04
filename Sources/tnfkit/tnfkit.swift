// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Engine
import Foundation
import MetalKit
import SwiftUI

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
public final class TNFEngine {
    private var device: MTLDevice?

    // Tool management
    private var tools: [EngineTools: ToolInterfaceProtocol] = [:]
    private var activeTool: EngineTools?
    private var areaSelectionTool: SelectionTool?

    private var viewportSize = vec2i(0, 0)

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        self.device = device

        areaSelectionTool = SelectionTool()

        areaSelectionTool?.setSelectionChangeHandler { points in
            points.toNDC().forEach { point in
                print("Selection point: \(point)")
            }
        }

        if let selectionTool = areaSelectionTool {
            tools[.select] = selectionTool
        }
    }

    public func start(with view: MTKView) {
        if activeTool == nil {
            selectTool(.select)
        }
        Log.error("view size: \(view.bounds.size)")
    }

    public func update(view: MTKView) {
        viewportSize = view.bounds.size.asVec2i

        if let activeTool = activeTool, let tool = tools[activeTool] {
            tool.onUpdate()
        }

    }

    func resize(to size: CGSize) {
    }

    public func getMetalDevice() -> MTLDevice? {
        return device
    }

    //NOTE: Below are the methods that are used to interact with the engine from the Editor
    //NOTE: Creates and returns the appropriate ViewportView for the current platform
    public func createViewport() -> ViewportView {
        return ViewportView(engine: self)
    }

    public func selectTool(_ toolType: EngineTools) {
    }

    public func selectionToolCallback(toolType: EngineTools) {
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

}
