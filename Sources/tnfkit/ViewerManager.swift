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
        self.cameraController.setDebugMode(true)

    }

    func start(view: MTKView) {
        guard let renderer = Renderer() else {
            Log.error("Failed to create renderer")
            return
        }
        self.renderer = renderer

        // Load and add the person.usdz model , might select vertices from it
        if let personMesh = Mesh(device: view.device!, modelPath: "person") {
            personMesh.setPosition(vec3f.up * -1)
            personMesh.setScale(vec3f.one * 0.01)
            personMesh.setRotation(angle: 180, axis: .x)
            renderer.addRenderable(personMesh)
            Log.info("Added person model to renderer")
        } else {
            Log.error("Failed to create person model")
        }

        // Add selector for interaction
        if let selector = Selector(device: view.device!, toolManager: toolManager) {
            renderer.addRenderable(selector)
            Log.info("Added selector to renderer")
        } else {
            Log.error("Failed to create selector")
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

        //Lock the camera if the tool is not control
        if toolManager.getActiveTool() == .control {
            cameraController.setEnabled(true)
        } else {
            cameraController.setEnabled(false)
        }
    }

    public func debugButton() {
        Log.error("Debug button pressed")
    }
}
