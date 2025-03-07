// Copyright (c) 2025 The Noughy Fox
// Created by: Alexei1R
// Date: 2025-03-06
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

        // Initialize selection render pass
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
        // Method kept for backward compatibility
    }

    public func resize(size: vec2i) {
        // Use the camera's built-in method to handle aspect ratio changes
        if let camera = currentCamera {
            let aspectRatio = Float(size.x) / Float(size.y)
            camera.setAspectRatio(aspectRatio)
        }

        // Resize the selection render pass
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

    // MARK: - Selection Rendering

    /// Initialize the selection render pass
    private func initializeSelectionPass() {
        guard let api = rendererAPI else {
            Log.error("Cannot initialize selection pass - no renderer API")
            return
        }

        self.selectionRenderPass = SelectionRenderPass(rendererAPI: api)

        // Get current view dimensions if available - ensure they are valid
        let width = max(Int(currentView.drawableSize.width), 64)
        let height = max(Int(currentView.drawableSize.height), 64)

        // Log the dimensions we're using
        Log.info("Initializing selection pass with dimensions: \(width) x \(height)")

        // Resize the selection pass with these dimensions
        selectionRenderPass?.resize(width: width, height: height)

        // We'll resize again when the view is properly sized
        if width == 64 || height == 64 {
            Log.warning(
                "Default minimum dimensions used for selection pass - will resize when view is ready"
            )
        }
    }

    /// Render selection areas to an off-screen texture
    private func renderSelectionPass() {
        guard let selectionRenderPass = selectionRenderPass,
            let camera = currentCamera
        else {
            return
        }

        // Create a command buffer for the selection pass
        let commandBuffer = rendererAPI.createCommandBuffer()
        commandBuffer.setLabel("SelectionPassCommandBuffer")

        // Begin the selection render pass
        guard
            let selectionEncoder = selectionRenderPass.beginSelectionPass(
                commandBuffer: commandBuffer)
        else {
            return
        }

        // Set a label to identify this encoder
        selectionEncoder.label = "SelectionPass"

        // Find any SelectionArea renderable to render
        for renderable in renderables {
            if let selectionArea = renderable as? SelectionArea {
                // Use the special selection pipeline for RGBA32Float format
                if let pipeline = selectionArea.getSelectionPipeline() {
                    // Bind the selection pipeline to the encoder
                    pipeline.bind(to: selectionEncoder)

                    // Draw using the renderable's draw method
                    selectionArea.draw(renderEncoder: selectionEncoder)
                } else {
                    Log.error("Missing selection pipeline for SelectionArea")
                }
                break  // Only render the first selection area found
            }
        }

        // End the encoder through the command buffer's tracking system
        // This avoids ending the encoder twice
        commandBuffer.endActiveEncoder()

        // Commit the command buffer and wait for it to complete
        // This ensures the selection texture is ready before it's used
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

