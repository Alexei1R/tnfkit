// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit
import SwiftUI

@MainActor
class ViewerManager {
    private let toolManager: ToolManager
    private var renderer: Renderer?
    private var currentCamera: Camera
    private var cameraController: CameraController

    public init(toolManager: ToolManager) {
        self.toolManager = toolManager
        //NOTE: Camera
        self.currentCamera = Camera.createDefaultCamera()
        self.cameraController = CameraController(camera: currentCamera)
        self.cameraController.setRotationSensitivity(5.0)
        self.cameraController.setZoomSensitivity(5.0)
        self.cameraController.setPanSensitivity(10.0)

    }

    func start(view: MTKView) {
        guard let renderer = Renderer() else {
            Log.error("Failed to create renderer")
            return
        }
        self.renderer = renderer
        // Create and add textured quad
        if let texturedQuad = TexturedQuad(device: view.device!, texturePath: "cat") {
            renderer.addRenderable(texturedQuad)
            Log.info("Added textured quad to renderer")
        } else {
            Log.error("Failed to create textured quad")
        }

    }

    func resize(size: vec2i) {
        currentCamera.setAspectRatio(Float(size.x) / Float(size.y))
        cameraController.setViewDimensions(
            width: Float(size.x),
            height: Float(size.y)
        )
    }

    func update(dt: Float, view: MTKView) {
        guard let renderer = renderer else { return }
        renderer.beginFrame(camera: currentCamera, deltaTime: dt)
        renderer.endFrame(view: view)
    }

    public func debugButton() {
        Log.error("Debug button pressed")
    }
}
