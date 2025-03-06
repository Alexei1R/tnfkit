// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import MetalKit

@MainActor
public class Renderer {
    private var currentView: MTKView
    private var rendererAPI: RendererAPI!
    private var renderables: [Renderable] = []

    // Drawing state management
    private var currentDrawable: CAMetalDrawable?
    private var currentRenderPassDescriptor: MTLRenderPassDescriptor?
    private var currentCamera: Camera?
    private var lastUpdateTime: TimeInterval
    private var lightPosition: vec3f = vec3f(5, 5, 5)

    public init?(view: MTKView) {
        self.currentView = view
        self.lastUpdateTime = CACurrentMediaTime()

        guard let api = RendererAPI() else {
            Log.error("Failed to create RendererAPI")
            return nil
        }
        self.rendererAPI = api
    }

    public func addRenderable(_ renderable: Renderable) {
        if renderable.prepare(rendererAPI: rendererAPI) {
            renderables.append(renderable)
        }
    }

    public func beginFrame(camera: Camera, view: MTKView) {
        self.currentView = view
        self.currentDrawable = view.currentDrawable
        self.currentRenderPassDescriptor = view.currentRenderPassDescriptor
        self.currentCamera = camera

        // Early exit if we can't render
        guard currentDrawable != nil, currentRenderPassDescriptor != nil else {
            return
        }

        let currentTime = CACurrentMediaTime()
        lastUpdateTime = currentTime

        // Update light position
        let lightOrbitRadius: Float = 5.0
        let rotationAngle = Float(currentTime) * 2
        lightPosition = vec3f(
            cos(rotationAngle) * lightOrbitRadius,
            2.0,
            sin(rotationAngle) * lightOrbitRadius
        )

        // Update each renderable with camera and light information
        for renderable in renderables {
            renderable.update(camera: camera, lightPosition: lightPosition)
        }
    }

    public func drawModel() {
        // Method kept for backward compatibility
    }

    public func resize(size: vec2i) {
        // Use the camera's built-in method to handle aspect ratio changes
        if let camera = currentCamera {
            let aspectRatio = Float(size.x) / Float(size.y)
            camera.setAspectRatio(aspectRatio)
        }
    }

    public func endFrame() {
        guard let drawable = currentDrawable,
            let renderPassDescriptor = currentRenderPassDescriptor,
            !renderables.isEmpty
        else {
            return
        }

        let commandBuffer = rendererAPI.createCommandBuffer()
        let renderEncoder = commandBuffer.beginRenderPass(descriptor: renderPassDescriptor)

        // Draw each renderable with its own pipeline and buffers
        for renderable in renderables {
            if let pipeline = renderable.getPipeline() {
                // Bind the renderable's pipeline to the encoder
                pipeline.bind(to: renderEncoder)

                // Draw using the renderable's draw method
                renderable.draw(renderEncoder: renderEncoder)
            }
        }

        commandBuffer.endActiveEncoder()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        // Selection render pass

        // Reset state for next frame
        currentDrawable = nil
        currentRenderPassDescriptor = nil
    }
}
