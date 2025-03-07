// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Metal

public class CommandBuffer {
    private let commandBuffer: MTLCommandBuffer
    private var activeEncoder: Any?
    private var currentEncoderType: EncoderType?

    public enum EncoderType {
        case render
        case compute
        case blit
    }

    public init(commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            Log.error("Failed to create command buffer")
            fatalError("Could not create command buffer")
        }
        self.commandBuffer = commandBuffer
    }

    /// Begin a render pass with the given descriptor
    @discardableResult
    public func beginRenderPass(descriptor: MTLRenderPassDescriptor) -> MTLRenderCommandEncoder {
        endActiveEncoder()

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            Log.error("Failed to create render command encoder")
            fatalError("Could not create render command encoder")
        }

        activeEncoder = encoder
        currentEncoderType = .render
        return encoder
    }

    /// Begin a compute pass
    @discardableResult
    public func beginComputePass() -> MTLComputeCommandEncoder {
        endActiveEncoder()

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            Log.error("Failed to create compute command encoder")
            fatalError("Could not create compute command encoder")
        }

        activeEncoder = encoder
        currentEncoderType = .compute
        return encoder
    }

    /// Begin a blit pass
    @discardableResult
    public func beginBlitPass() -> MTLBlitCommandEncoder {
        endActiveEncoder()

        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            Log.error("Failed to create blit command encoder")
            fatalError("Could not create blit command encoder")
        }

        activeEncoder = encoder
        currentEncoderType = .blit
        return encoder
    }

    /// Get the current render encoder if active
    public func getRenderEncoder() -> MTLRenderCommandEncoder? {
        guard currentEncoderType == .render else {
            return nil
        }
        return activeEncoder as? MTLRenderCommandEncoder
    }

    /// Get the current compute encoder if active
    public func getComputeEncoder() -> MTLComputeCommandEncoder? {
        guard currentEncoderType == .compute else {
            return nil
        }
        return activeEncoder as? MTLComputeCommandEncoder
    }

    /// Get the current blit encoder if active
    public func getBlitEncoder() -> MTLBlitCommandEncoder? {
        guard currentEncoderType == .blit else {
            return nil
        }
        return activeEncoder as? MTLBlitCommandEncoder
    }

    /// End the current encoder if one is active
    public func endActiveEncoder() {
        switch currentEncoderType {
        case .render:
            (activeEncoder as? MTLRenderCommandEncoder)?.endEncoding()
        case .compute:
            (activeEncoder as? MTLComputeCommandEncoder)?.endEncoding()
        case .blit:
            (activeEncoder as? MTLBlitCommandEncoder)?.endEncoding()
        case nil:
            break
        }

        activeEncoder = nil
        currentEncoderType = nil
    }

    /// Present a drawable
    public func present(_ drawable: MTLDrawable) {
        commandBuffer.present(drawable)
    }

    /// Commit the command buffer
    public func commit() {
        endActiveEncoder()
        commandBuffer.commit()
    }

    /// Commit and wait for the command buffer to complete
    public func commitAndWait() {
        endActiveEncoder()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// Add a completion handler
    public func addCompletionHandler(_ handler: @escaping () -> Void) {
        commandBuffer.addCompletedHandler { _ in
            handler()
        }
    }

    /// Add a labeled completion handler
    public func addCompletionHandler(label: String, _ handler: @escaping () -> Void) {
        commandBuffer.addCompletedHandler { [label] _ in
            Log.debug("Command buffer completed: \(label)")
            handler()
        }
    }

    /// Set a label for the command buffer
    public func setLabel(_ label: String) {
        commandBuffer.label = label
    }

    public func clearActiveEncoder() {
        activeEncoder = nil
        currentEncoderType = nil
    }
}
