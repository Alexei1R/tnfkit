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
    private var depthTexture: Texture?
    private let device: MTLDevice
    private var width: Int = 64
    private var height: Int = 64
    private let minDimension: Int = 64
    private var isReady: Bool = false
    private let selectionFormat: MTLPixelFormat = .r8Uint

    public init?(device: MTLDevice, name: String = "SelectionRenderPass") {
        self.device = device
        self.renderPass = RenderPass(device: device, name: name)

        guard setupTextures(width: minDimension, height: minDimension) else {
            Log.error("Failed to initialize SelectionRenderPass")
            return nil
        }
    }

    public func resize(width: Int, height: Int) -> Bool {
        let safeWidth = max(width, minDimension)
        let safeHeight = max(height, minDimension)

        if self.width == safeWidth && self.height == safeHeight && isReady {
            return true
        }

        self.width = safeWidth
        self.height = safeHeight

        return setupTextures(width: safeWidth, height: safeHeight)
    }

    private func setupTextures(width: Int, height: Int) -> Bool {
        // NOTE: R8Uint is efficient for binary masking in selection
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

        guard
            let newDepthTexture = Texture.createDepthTexture(
                device: device,
                width: width,
                height: height,
                pixelFormat: .depth32Float,
                label: "SelectionDepthTexture"
            )
        else {
            Log.error("Failed to create depth texture for selection pass")
            return false
        }

        selectionTexture = newSelectionTexture
        depthTexture = newDepthTexture

        renderPass.setColorAttachment(
            index: 0,
            texture: newSelectionTexture,
            loadAction: .clear,
            storeAction: .store,
            clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        )

        renderPass.setDepthAttachment(
            texture: newDepthTexture,
            loadAction: .clear,
            storeAction: .dontCare,
            clearDepth: 1.0
        )

        isReady = true
        Log.info("Selection render pass resized to \(width) x \(height)")
        return true
    }

    public func begin(commandBuffer: CommandBuffer) -> MTLRenderCommandEncoder? {
        guard isReady, selectionTexture != nil else {
            Log.error("Selection render pass not ready or texture missing")
            return nil
        }

        return commandBuffer.beginRenderPass(descriptor: renderPass.descriptor())
    }

    public func getSelectionTexture() -> Texture? {
        return selectionTexture
    }

    public func getSelectionMTLTexture() -> MTLTexture? {
        return selectionTexture?.getMetalTexture()
    }

    public func getDescriptor() -> MTLRenderPassDescriptor {
        return renderPass.descriptor()
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

    public func setSelectionFormat(_ format: MTLPixelFormat) -> Bool {
        if isReady {
            Log.error("Cannot change selection format after initialization")
            return false
        }

        if format != .r8Uint && format != .rgba8Uint && format != .rgba32Float {
            Log.error("Unsupported selection format: \(format)")
            return false
        }

        return true
    }

    public func saveToFile(url: URL, commandQueue: MTLCommandQueue) -> Bool {
        guard let texture = selectionTexture?.getMetalTexture() else {
            Log.error("No selection texture to save")
            return false
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        guard let stagingTexture = device.makeTexture(descriptor: descriptor) else {
            Log.error("Failed to create staging texture")
            return false
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            Log.error("Failed to create command buffer or blit encoder")
            return false
        }

        blitEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
            to: stagingTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        Log.info("Selection mask saved to: \(url.path)")
        return true
    }
}

