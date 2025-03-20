// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

@MainActor
public class SelectionRenderPass {
    private var renderPass: RenderPass
    private var selectionTexture: Texture?
    private let device: MTLDevice
    private var width: Int = 64
    private var height: Int = 64
    private let minDimension: Int = 64
    private var isReady: Bool = false
    private let selectionFormat: MTLPixelFormat = .r8Uint
    private var lastResizeWidth: Int = 0
    private var lastResizeHeight: Int = 0

    public init?(device: MTLDevice, name: String = "SelectionRenderPass") {
        self.device = device
        
        self.renderPass = RenderPass(device: device, name: name)

        guard setupTextures(width: minDimension, height: minDimension) else {
            Log.error("Failed to initialize SelectionRenderPass")
            return nil
        }

        lastResizeWidth = minDimension
        lastResizeHeight = minDimension
    }

    public func resize(width: Int, height: Int) -> Bool {
        let safeWidth = max(width, minDimension)
        let safeHeight = max(height, minDimension)

        // Check if dimensions actually changed from last resize operation
        if safeWidth == lastResizeWidth && safeHeight == lastResizeHeight && isReady {
            return true
        }

        Log.info(
            "Resizing selection texture from \(lastResizeWidth)x\(lastResizeHeight) to \(safeWidth)x\(safeHeight)"
        )

        // Update tracking variables
        self.width = safeWidth
        self.height = safeHeight
        lastResizeWidth = safeWidth
        lastResizeHeight = safeHeight

        return setupTextures(width: safeWidth, height: safeHeight)
    }

    private func setupTextures(width: Int, height: Int) -> Bool {
        // Create an r8Uint texture which is efficient for binary masking in selection
        guard
            let newSelectionTexture = Texture.createRenderTarget(
                device: device,
                width: width,
                height: height,
                pixelFormat: selectionFormat,
                label: "SelectionMaskTexture"
            )
        else {
            Log.error("Failed to create selection texture")
            return false
        }

        selectionTexture = newSelectionTexture

        renderPass.setColorAttachment(
            index: 0,
            texture: newSelectionTexture,
            loadAction: .clear,
            storeAction: .store,
            clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        )

        isReady = true
        Log.info("Selection render pass resized to \(width) x \(height)")
        return true
    }

    public func getDescriptor() -> MTLRenderPassDescriptor {
        return renderPass.descriptor()
    }

    public func getSelectionTexture() -> Texture? {
        return selectionTexture
    }

    public func getSelectionMTLTexture() -> MTLTexture? {
        return selectionTexture?.getMetalTexture()
    }

    public func clear(commandBuffer: CommandBuffer) {
        guard isReady else {
            return
        }
        
        let encoder = commandBuffer.beginRenderPass(descriptor: renderPass.descriptor())
        commandBuffer.endActiveEncoder()
    }

    public var isAvailable: Bool {
        return isReady && selectionTexture != nil
    }

    public var dimensions: (width: Int, height: Int) {
        return (width, height)
    }

    public func bindToComputeShader(encoder: MTLComputeCommandEncoder, index: Int = 0) {
        guard let texture = selectionTexture else {
            Log.error("Cannot bind selection texture - not initialized")
            return
        }

        texture.bindCompute(to: encoder, at: index)
    }

    public func bindToRenderShader(
        encoder: MTLRenderCommandEncoder, index: Int = 0, stage: ShaderStage = .fragment
    ) {
        guard let texture = selectionTexture else {
            Log.error("Cannot bind selection texture - not initialized")
            return
        }

        texture.bind(to: encoder, at: index, for: stage)
    }
}
