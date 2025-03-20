// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

@MainActor
public class Renderer {
    private var rendererAPI: RendererAPI!
    private var currentCamera: Camera?
    private var renderables: [RenderablePrimitive] = []

    //NOTE: Selection pass
    private var selectionPass: SelectionRenderPass?

    public init?() {
        guard let api = RendererAPI() else {
            Log.error("Failed to create RendererAPI")
            return nil
        }
        self.rendererAPI = api
        self.selectionPass = SelectionRenderPass(device: api.device)
    }

    //NOTE: Add a renderable to the renderer
    public func addRenderable(_ renderable: RenderablePrimitive) {
        renderables.append(renderable)
    }

    public func beginFrame(camera: Camera, deltaTime: Float) {
        self.currentCamera = camera

        // Update all renderables
        for renderable in renderables {
            renderable.update(deltaTime: deltaTime)
        }
    }

    public func processSelectionPass() {
        //NOTE: The selection pass for the selection tool
        guard let selectionPass = selectionPass, let currentCamera = currentCamera else {
            Log.error("SelectionPass or Camera is not initialized")
            return
        }

        // Make sure the selection pass is ready
        if !selectionPass.isAvailable {
            Log.error("Selection pass is not available")
            return
        }

        let commandBuffer = rendererAPI.createCommandBuffer()
        commandBuffer.setLabel("SelectionPassCommandBuffer")

        // Begin render pass with the selection descriptor
        let selectionEncoder = commandBuffer.beginRenderPass(
            descriptor: selectionPass.getDescriptor())

        // Draw selection-eligible renderables
        for renderable in renderables {
            if renderable.isVisible && renderable.isSelectionTool {
                renderable.prepareSelection(commandEncoder: selectionEncoder, camera: currentCamera)
                renderable.renderSelection(commandEncoder: selectionEncoder)
            }
        }

        // End encoding and commit
        commandBuffer.endActiveEncoder()
        commandBuffer.commit()
    }

    public func endFrame(view: MTKView) {

        //NOTE: The dafalut rendering pass
        guard let rendererAPI = rendererAPI, let currentCamera = currentCamera else {
            Log.error("RendererAPI or Camera is not initialized")
            return
        }
        guard let currentDrawable = view.currentDrawable else {
            Log.error("Failed to get currentDrawable")
            return
        }

        //NOTE: Main render pass
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            Log.error("Failed to get renderPassDescriptor")
            return
        }

        let commandBuffer = rendererAPI.createCommandBuffer()
        let renderEncoder = commandBuffer.beginRenderPass(descriptor: renderPassDescriptor)

        //NOTE: Draw all renderables
        for renderable in renderables {
            if renderable.isVisible {
                renderable.prepare(commandEncoder: renderEncoder, camera: currentCamera)
                renderable.render(commandEncoder: renderEncoder)
            }
        }

        commandBuffer.endActiveEncoder()
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()

    }

    public func resize(size: vec2i) {
        selectionPass?.resize(width: Int(size.x), height: Int(size.y))
    }
}
