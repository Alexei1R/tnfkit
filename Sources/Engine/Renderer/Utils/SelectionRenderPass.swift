// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import Metal
import MetalKit

@MainActor
public class SelectionRenderPass {
    // Texture for storing selection results
    private var selectionTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var renderPassDescriptor: MTLRenderPassDescriptor
    private var renderPass: RenderPass

    // Reference to renderer API
    private weak var rendererAPI: RendererAPI?

    // Dimensions for the selection texture
    private var textureDimensions: vec2i = vec2i(1, 1)

    // Minimum dimensions to ensure valid textures
    private let minDimension: Int = 64

    // Keep track if ready to use
    private var isReady: Bool = false

    public init(rendererAPI: RendererAPI) {
        self.rendererAPI = rendererAPI
        self.renderPassDescriptor = MTLRenderPassDescriptor()
        self.renderPass = RenderPass()

        // Initialize with safe minimum dimensions
        setupTextures(width: minDimension, height: minDimension)
    }

    /// Resize the selection textures to match the view size
    public func resize(width: Int, height: Int) {
        // Validate dimensions to ensure they're positive
        let safeWidth = max(width, minDimension)
        let safeHeight = max(height, minDimension)

        // No need to resize if dimensions are the same and textures are already created
        if textureDimensions.x == safeWidth && textureDimensions.y == safeHeight && isReady {
            return
        }

        textureDimensions = vec2i(Int32(safeWidth), Int32(safeHeight))
        setupTextures(width: safeWidth, height: safeHeight)

        Log.info("Selection render pass resized to \(safeWidth) x \(safeHeight)")
    }

    /// Create or recreate the selection and depth textures
    private func setupTextures(width: Int, height: Int) {
        guard let device = rendererAPI?.device else {
            Log.error("Cannot create selection textures - no Metal device")
            isReady = false
            return
        }

        // Ensure dimensions are valid
        let validWidth = max(width, minDimension)
        let validHeight = max(height, minDimension)

        // Create texture descriptor for selection texture (RGBA for storing IDs)
        let selectionTextureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,  // High precision for IDs or custom data
            width: validWidth,
            height: validHeight,
            mipmapped: false)
        selectionTextureDesc.usage = [.renderTarget, .shaderRead]
        selectionTextureDesc.storageMode = .private

        // Create texture descriptor for depth
        let depthTextureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: validWidth,
            height: validHeight,
            mipmapped: false)
        depthTextureDesc.usage = [.renderTarget]
        depthTextureDesc.storageMode = .private

        // Log dimensions for debugging
        Log.info("Creating selection textures with dimensions \(validWidth) x \(validHeight)")

        // Create the textures
        selectionTexture = device.makeTexture(descriptor: selectionTextureDesc)
        depthTexture = device.makeTexture(descriptor: depthTextureDesc)

        // Verify creation succeeded
        guard selectionTexture != nil, depthTexture != nil else {
            Log.error("Failed to create selection or depth texture")
            isReady = false
            return
        }

        // Configure the render pass descriptor with these textures
        configureRenderPass()
        isReady = true
    }

    /// Configure the render pass with current textures
    private func configureRenderPass() {
        renderPass.setColorAttachment(
            index: 0,
            texture: selectionTexture,
            loadAction: .clear,
            storeAction: .store,
            clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)  // Clear to transparent
        )

        renderPass.setDepthAttachment(
            texture: depthTexture,
            loadAction: .clear,
            storeAction: .dontCare,
            clearDepth: 1.0
        )

        renderPassDescriptor = renderPass.get()
    }

    /// Begin a selection rendering pass
    public func beginSelectionPass(commandBuffer: CommandBuffer) -> MTLRenderCommandEncoder? {
        guard isReady, let selectionTexture = selectionTexture else {
            Log.error("Selection render pass not ready or texture missing")
            return nil
        }

        // Use the existing command buffer to create a render encoder with our descriptor
        return commandBuffer.beginRenderPass(descriptor: renderPassDescriptor)
    }

    /// Get the selection texture for reading or processing
    public func getSelectionTexture() -> MTLTexture? {
        return selectionTexture
    }
}

