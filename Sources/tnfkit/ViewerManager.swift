// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Engine
import Foundation
import MetalKit
import SwiftUI

struct SelectionVertex {
    var position: SIMD2<Float>
}

class ViewerManager {
    private let toolManager: ToolManager
    private var renderer: Renderer?

    private var curentCamera: Camera

    public init(toolManager: ToolManager) {
        self.toolManager = toolManager
        //NOTE: Set the selection change handler
        let localToolManager = toolManager
        Task { @MainActor @Sendable in
            if let selectionTool = localToolManager.getTool(.select) as? SelectionTool {
                selectionTool.setSelectionChangeHandler { points in
                    points.forEach {
                        Log.info($0)
                    }
                }
            }
        }

        self.curentCamera = Camera.createDefaultCamera()
    }

    deinit {}

    //NOTE: to be call
    func start(view: MTKView) {
        renderer = Renderer(view: view)
    }

    func resize(size: vec2i) {
        renderer?.resize(size: size)
    }

    func update(dt: Float, view: MTKView) {
        guard let renderer = renderer else {
            return
        }

        renderer.beginFrame(camera: curentCamera)

        //NOTE: Draw

        renderer.endFrame()
    }
}

