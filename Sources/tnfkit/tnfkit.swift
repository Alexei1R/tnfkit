// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Engine
import Foundation
import MetalKit
import SwiftUI

@MainActor
public final class TNFEngine {
    private var device: MTLDevice?

    private var toolManager: ToolManager

    //NOTE: List of modules
    private let moduleStack: ModuleStack

    //NOTE: Renderer stuff
    private let viewer: ViewerManager

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            Log.error("Failed to create Metal device ")
            return nil
        }

        self.device = device

        //NOTE:Initialize the module stack
        self.moduleStack = ModuleStack()

        //NOTE: Initialize the managers
        toolManager = ToolManager()
        // Default tool will be set during ToolManager initialization

        viewer = ViewerManager(toolManager: toolManager)
        //NOTE: Initialize modules
    }

    public func addModule(_ module: Module) {
        moduleStack.addModule(module)
    }

    public func removeModule(_ module: Module) {
        moduleStack.removeModule(module)
    }

    public func start(with view: MTKView) {
        // Make sure Control tool is selected
        if toolManager.getActiveTool() != .control {
            selectTool(.control)
        }

        Log.info(
            "Starting engine with active tool: \(toolManager.getActiveTool()?.toString() ?? "none")"
        )
        viewer.start(view: view)
    }

    public func update(view: MTKView) {
        toolManager.updateActiveTool()
        moduleStack.updateAll(dt: 1.0 / 60.0)
        viewer.update(dt: 1 / 60, view: view)
    }

    func resize(to size: CGSize) {
        viewer.resize(size: size.asVec2i)
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
        toolManager.selectTool(toolType)
    }

    public func selectionToolCallback(toolType: EngineTools) {
        toolManager.selectTool(toolType)
    }
}

