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
class ViewerManager {
    private let toolManager: ToolManager
    private var renderer: Renderer?
    private var currentCamera: Camera
    private var models: [StaticModel] = []
    private var rotationAngle: Float = 0.0
    private var lastUpdateTime = CACurrentMediaTime()

    public init(toolManager: ToolManager) {
        self.toolManager = toolManager
        self.currentCamera = Camera.createDefaultCamera()

        configureToolManager()
    }

    private func configureToolManager() {
        Task { @MainActor @Sendable in
            if let selectionTool = toolManager.getTool(.select) as? SelectionTool {
                selectionTool.setSelectionChangeHandler { points in
                    points.toNDC().forEach {
                        Log.info($0)
                    }
                }
            }
        }
    }

    func start(view: MTKView) {
        guard let renderer = Renderer(view: view) else {
            Log.error("Failed to create renderer")
            return
        }
        self.renderer = renderer

        //NOTE: Here i setup the models
        let model = StaticModel(modelPath: "model")
        model.transform = mat4f.identity
            .translate(vec3f(0, 0, 0))
            .rotateDegrees(-90.0, axis: .x)

        models.append(model)
        renderer.addRenderable(model)

    }

    func resize(size: vec2i) {
        currentCamera.setAspectRatio(Float(size.x) / Float(size.y))
        renderer?.resize(size: size)
    }

    func update(dt: Float, view: MTKView) {
        guard let renderer = renderer else { return }

        renderer.beginFrame(camera: currentCamera, view: view)
        renderer.drawModel()
        renderer.endFrame()
    }
}
