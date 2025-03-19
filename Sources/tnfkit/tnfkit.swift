// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Engine
import Foundation
import MetalKit
import SwiftUI
import Combine

// Separate the class identity from MainActor isolation
public final class TNFEngineIdentifier: Equatable, Hashable {
    let id = UUID()
    
    public static func == (lhs: TNFEngineIdentifier, rhs: TNFEngineIdentifier) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
public final class TNFEngine: ObservableObject {
    // Use identifier for equality checking
    public let identifier = TNFEngineIdentifier()
    private var device: MTLDevice?

    private var toolManager: ToolManager

    //NOTE: List of modules
    private let moduleStack: ModuleStack

    //NOTE: Renderer stuff
    private let viewer: ViewerManager
    
    // For bone assignment and animation
    private var boneViewModelReference: Any?

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
    
    public func getSelectableModel() -> Any? {
        return viewer.getSelectableModel()
    }
    
    public func registerBoneViewModel(_ viewModel: Any) {
        self.boneViewModelReference = viewModel
        
        // Pass selectable model to the view model
        if let selectionModel = getSelectableModel() {
            print("🔄 Found selectable model: \(selectionModel)")
            
            if let object = viewModel as? NSObject {
                // Try KVC first (most reliable in Swift)
                if object.responds(to: #selector(NSObject.setValue(_:forKey:))) {
                    print("🔄 Setting model via KVC")
                    object.setValue(selectionModel, forKey: "selectionModel")
                } else {
                    // Fall back to selector approach
                    print("🔄 Setting model via selector")
                    let selector = NSSelectorFromString("setSelectionModel:")
                    if object.responds(to: selector) {
                        object.perform(selector, with: selectionModel)
                    } else {
                        print("❌ View model doesn't respond to setSelectionModel:")
                    }
                }
            } else {
                print("❌ View model is not an NSObject")
            }
        } else {
            print("❌ No selectable model found")
        }
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
