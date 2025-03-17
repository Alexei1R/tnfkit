// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

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

    private var time = Time()

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
        if toolManager.getActiveTool() != .control {
            selectTool(.control)
        }

        Log.info(
            "Starting engine with active tool: \(toolManager.getActiveTool()?.toString() ?? "none")"
        )
        viewer.start(view: view)
    }

    public func update(view: MTKView) {
        time.update()

        toolManager.updateActiveTool()
        moduleStack.updateAll(dt: Float(time.deltaTimeFloat))
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

    public func debugButton() {
        viewer.debugButton()
    }
}
