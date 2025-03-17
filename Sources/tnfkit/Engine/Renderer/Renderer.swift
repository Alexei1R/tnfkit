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

    public init?() {
        guard let api = RendererAPI() else {
            Log.error("Failed to create RendererAPI")
            return nil
        }
        self.rendererAPI = api
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

    public func endFrame(view: MTKView) {
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
}
