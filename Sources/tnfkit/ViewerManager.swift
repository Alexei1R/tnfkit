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

    public init(toolManager: ToolManager) {
        self.toolManager = toolManager
        self.currentCamera = Camera.createDefaultCamera()

    }

    func start(view: MTKView) {
        guard let renderer = Renderer() else {
            Log.error("Failed to create renderer")
            return
        }
        self.renderer = renderer

    }

    func resize(size: vec2i) {
        currentCamera.setAspectRatio(Float(size.x) / Float(size.y))
    }

    func update(dt: Float, view: MTKView) {
        guard let renderer = renderer else { return }

        renderer.beginFrame(camera: currentCamera)

        renderer.endFrame(view: view)
    }
}
