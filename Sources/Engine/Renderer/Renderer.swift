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
    public let rendererAPI: RendererAPI!  // Public for ModelSelectionProcessor
    private var renderables: [Renderable] = []

    // Selection render pass
    private var selectionRenderPass: SelectionRenderPass?

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

        initializeSelectionPass()
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
    }

    public func resize(size: vec2i) {
        if let camera = currentCamera {
            let aspectRatio = Float(size.x) / Float(size.y)
            camera.setAspectRatio(aspectRatio)
        }

        resizeSelectionPass(size: size)
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

        for renderable in renderables {
            if let pipeline = renderable.getPipeline() {
                pipeline.bind(to: renderEncoder)

                renderable.draw(renderEncoder: renderEncoder)
            }
        }

        commandBuffer.endActiveEncoder()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        // Selection render pass - only run if selection is active
        if let selectionArea = renderables.first(where: { $0 is SelectionArea }) as? SelectionArea {
            if selectionArea.hasSelection {
                renderSelectionPass()
            }
        }

        // Reset state for next frame
        currentDrawable = nil
        currentRenderPassDescriptor = nil
    }

    private func initializeSelectionPass() {
        guard let api = rendererAPI else {
            Log.error("Cannot initialize selection pass - no renderer API")
            return
        }

        self.selectionRenderPass = SelectionRenderPass(rendererAPI: api)

        // Get current view dimensions if available - ensure they are valid
        let width = max(Int(currentView.drawableSize.width), 64)
        let height = max(Int(currentView.drawableSize.height), 64)

        Log.info("Initializing selection pass with dimensions: \(width) x \(height)")

        selectionRenderPass?.resize(width: width, height: height)

        if width == 64 || height == 64 {
            Log.warning(
                "Default minimum dimensions used for selection pass - will resize when view is ready"
            )
        }
    }

    private func renderSelectionPass() {
        guard let selectionRenderPass = selectionRenderPass,
            let camera = currentCamera
        else {
            return
        }

        let commandBuffer = rendererAPI.createCommandBuffer()
        commandBuffer.setLabel("SelectionPassCommandBuffer")

        guard
            let selectionEncoder = selectionRenderPass.beginSelectionPass(
                commandBuffer: commandBuffer)
        else {
            return
        }

        selectionEncoder.label = "SelectionPass"

        for renderable in renderables {
            if let selectionArea = renderable as? SelectionArea {
                if let pipeline = selectionArea.getSelectionPipeline() {
                    pipeline.bind(to: selectionEncoder)

                    selectionArea.draw(renderEncoder: selectionEncoder)
                } else {
                    Log.error("Missing selection pipeline for SelectionArea")
                }
                break
            }
        }

        commandBuffer.endActiveEncoder()
        commandBuffer.commitAndWait()
    }

    /// Update the selection render pass when view is resized
    private func resizeSelectionPass(size: vec2i) {
        if size.x > 0 && size.y > 0 {
            selectionRenderPass?.resize(width: Int(size.x), height: Int(size.y))
        }
    }

    /// Get the selection texture for processing
    public func getSelectionTexture() -> MTLTexture? {
        return selectionRenderPass?.getSelectionTexture()
    }
}
