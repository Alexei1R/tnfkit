// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import MetalKit

public enum RenderPassLoadAction {
    case clear
    case load
    case dontCare

    var mtlLoadAction: MTLLoadAction {
        switch self {
        case .clear: return .clear
        case .load: return .load
        case .dontCare: return .dontCare
        }
    }
}

public enum RenderPassStoreAction {
    case store
    case dontCare
    case multisampleResolve
    case storeAndMultisampleResolve

    var mtlStoreAction: MTLStoreAction {
        switch self {
        case .store: return .store
        case .dontCare: return .dontCare
        case .multisampleResolve: return .multisampleResolve
        case .storeAndMultisampleResolve: return .storeAndMultisampleResolve
        }
    }
}

public struct RenderPassConfig {
    public var name: String
    public var colorAttachments:
        [(
            texture: Texture?,
            loadAction: RenderPassLoadAction,
            storeAction: RenderPassStoreAction,
            clearColor: MTLClearColor,
            resolveTexture: Texture?
        )] = []

    public var depthAttachment:
        (
            texture: Texture?,
            loadAction: RenderPassLoadAction,
            storeAction: RenderPassStoreAction,
            clearDepth: Double
        )?

    public var stencilAttachment:
        (
            texture: Texture?,
            loadAction: RenderPassLoadAction,
            storeAction: RenderPassStoreAction,
            clearStencil: UInt32
        )?

    public var sampleCount: Int = 1
    public var rasterizationRateMap: MTLRasterizationRateMap?

    public init(name: String) {
        self.name = name
    }
}

public final class RenderPass {
    private let device: MTLDevice
    private var renderPassDescriptor: MTLRenderPassDescriptor
    private var config: RenderPassConfig

    public init(device: MTLDevice, name: String = "RenderPass") {
        self.device = device
        self.config = RenderPassConfig(name: name)
        self.renderPassDescriptor = MTLRenderPassDescriptor()
    }

    public init(device: MTLDevice, config: RenderPassConfig) {
        self.device = device
        self.config = config
        self.renderPassDescriptor = MTLRenderPassDescriptor()
        configureFromConfig()
    }

    private func configureFromConfig() {
        for (index, attachment) in config.colorAttachments.enumerated() {
            let colorAttachment = renderPassDescriptor.colorAttachments[index]
            colorAttachment?.texture = attachment.texture?.getMetalTexture()
            colorAttachment?.loadAction = attachment.loadAction.mtlLoadAction
            colorAttachment?.storeAction = attachment.storeAction.mtlStoreAction
            colorAttachment?.clearColor = attachment.clearColor
            colorAttachment?.resolveTexture = attachment.resolveTexture?.getMetalTexture()
        }

        if let depth = config.depthAttachment {
            renderPassDescriptor.depthAttachment.texture = depth.texture?.getMetalTexture()
            renderPassDescriptor.depthAttachment.loadAction = depth.loadAction.mtlLoadAction
            renderPassDescriptor.depthAttachment.storeAction = depth.storeAction.mtlStoreAction
            renderPassDescriptor.depthAttachment.clearDepth = depth.clearDepth
        }

        if let stencil = config.stencilAttachment {
            renderPassDescriptor.stencilAttachment.texture = stencil.texture?.getMetalTexture()
            renderPassDescriptor.stencilAttachment.loadAction = stencil.loadAction.mtlLoadAction
            renderPassDescriptor.stencilAttachment.storeAction = stencil.storeAction.mtlStoreAction
            renderPassDescriptor.stencilAttachment.clearStencil = stencil.clearStencil
        }

        renderPassDescriptor.rasterizationRateMap = config.rasterizationRateMap
    }

    @discardableResult
    public func setColorAttachment(
        index: Int = 0,
        texture: Texture?,
        loadAction: RenderPassLoadAction = .clear,
        storeAction: RenderPassStoreAction = .store,
        clearColor: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    ) -> RenderPass {
        while config.colorAttachments.count <= index {
            config.colorAttachments.append((nil, .clear, .store, MTLClearColor(), nil))
        }

        let resolveTexture = config.colorAttachments[index].resolveTexture
        config.colorAttachments[index] = (
            texture, loadAction, storeAction, clearColor, resolveTexture
        )

        let attachment = renderPassDescriptor.colorAttachments[index]
        attachment?.texture = texture?.getMetalTexture()
        attachment?.loadAction = loadAction.mtlLoadAction
        attachment?.storeAction = storeAction.mtlStoreAction
        attachment?.clearColor = clearColor

        return self
    }

    @discardableResult
    public func setColorClearColor(
        index: Int = 0,
        clearColor: MTLClearColor
    ) -> RenderPass {
        guard index < config.colorAttachments.count else {
            Log.warning("Cannot set clear color: color attachment index \(index) does not exist")
            return self
        }

        let attachment = config.colorAttachments[index]
        config.colorAttachments[index] = (
            attachment.texture,
            attachment.loadAction,
            attachment.storeAction,
            clearColor,
            attachment.resolveTexture
        )

        renderPassDescriptor.colorAttachments[index]?.clearColor = clearColor
        return self
    }

    @discardableResult
    public func setResolveTexture(
        index: Int = 0,
        texture: Texture?
    ) -> RenderPass {
        guard index < config.colorAttachments.count else {
            Log.warning(
                "Cannot set resolve texture: color attachment index \(index) does not exist")
            return self
        }

        let attachment = config.colorAttachments[index]

        config.colorAttachments[index] = (
            attachment.texture,
            attachment.loadAction,
            attachment.storeAction,
            attachment.clearColor,
            texture
        )

        renderPassDescriptor.colorAttachments[index]?.resolveTexture = texture?.getMetalTexture()

        // NOTE: Automatically update store action when setting a resolve texture
        if texture != nil && attachment.storeAction != .multisampleResolve
            && attachment.storeAction != .storeAndMultisampleResolve
        {
            let newStoreAction: RenderPassStoreAction =
                (attachment.storeAction == .store)
                ? .storeAndMultisampleResolve : .multisampleResolve

            config.colorAttachments[index].storeAction = newStoreAction
            renderPassDescriptor.colorAttachments[index]?.storeAction =
                newStoreAction.mtlStoreAction
        }

        return self
    }

    @discardableResult
    public func setDepthAttachment(
        texture: Texture?,
        loadAction: RenderPassLoadAction = .clear,
        storeAction: RenderPassStoreAction = .dontCare,
        clearDepth: Double = 1.0
    ) -> RenderPass {
        config.depthAttachment = (texture, loadAction, storeAction, clearDepth)

        renderPassDescriptor.depthAttachment.texture = texture?.getMetalTexture()
        renderPassDescriptor.depthAttachment.loadAction = loadAction.mtlLoadAction
        renderPassDescriptor.depthAttachment.storeAction = storeAction.mtlStoreAction
        renderPassDescriptor.depthAttachment.clearDepth = clearDepth

        return self
    }

    @discardableResult
    public func setStencilAttachment(
        texture: Texture?,
        loadAction: RenderPassLoadAction = .clear,
        storeAction: RenderPassStoreAction = .dontCare,
        clearStencil: UInt32 = 0
    ) -> RenderPass {
        config.stencilAttachment = (texture, loadAction, storeAction, clearStencil)

        renderPassDescriptor.stencilAttachment.texture = texture?.getMetalTexture()
        renderPassDescriptor.stencilAttachment.loadAction = loadAction.mtlLoadAction
        renderPassDescriptor.stencilAttachment.storeAction = storeAction.mtlStoreAction
        renderPassDescriptor.stencilAttachment.clearStencil = clearStencil

        return self
    }

    // NOTE: Combined method for both depth and stencil when using a shared texture
    @discardableResult
    public func setDepthStencilAttachment(
        texture: Texture?,
        depthLoadAction: RenderPassLoadAction = .clear,
        depthStoreAction: RenderPassStoreAction = .dontCare,
        clearDepth: Double = 1.0,
        stencilLoadAction: RenderPassLoadAction = .clear,
        stencilStoreAction: RenderPassStoreAction = .dontCare,
        clearStencil: UInt32 = 0
    ) -> RenderPass {
        guard let texture = texture, texture.isDepthTexture() && texture.isStencilTexture() else {
            Log.error("Texture is not a valid depth-stencil format")
            return self
        }

        setDepthAttachment(
            texture: texture,
            loadAction: depthLoadAction,
            storeAction: depthStoreAction,
            clearDepth: clearDepth
        )

        setStencilAttachment(
            texture: texture,
            loadAction: stencilLoadAction,
            storeAction: stencilStoreAction,
            clearStencil: clearStencil
        )

        return self
    }

    @discardableResult
    public func setRasterizationRateMap(_ map: MTLRasterizationRateMap?) -> RenderPass {
        config.rasterizationRateMap = map
        renderPassDescriptor.rasterizationRateMap = map
        return self
    }

    public func descriptor() -> MTLRenderPassDescriptor {
        return renderPassDescriptor
    }

    public func colorTexture(at index: Int = 0) -> Texture? {
        guard index < config.colorAttachments.count else { return nil }
        return config.colorAttachments[index].texture
    }

    public func depthTexture() -> Texture? {
        return config.depthAttachment?.texture
    }

    public func stencilTexture() -> Texture? {
        return config.stencilAttachment?.texture
    }

    public func begin(commandBuffer: MTLCommandBuffer) -> MTLRenderCommandEncoder? {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            Log.error("Failed to create render command encoder")
            return nil
        }

        encoder.label = config.name
        return encoder
    }

    // NOTE: Factory methods for common rendering scenarios
    public static func createDefault(
        device: MTLDevice,
        colorTexture: Texture,
        depthTexture: Texture? = nil,
        name: String = "DefaultRenderPass"
    ) -> RenderPass {
        let renderPass = RenderPass(device: device, name: name)

        renderPass.setColorAttachment(
            texture: colorTexture,
            loadAction: .clear,
            storeAction: .store,
            clearColor: MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        )

        if let depthTexture = depthTexture {
            renderPass.setDepthAttachment(
                texture: depthTexture,
                loadAction: .clear,
                storeAction: .dontCare
            )
        }

        return renderPass
    }

    public static func createOffscreen(
        device: MTLDevice,
        width: Int,
        height: Int,
        colorFormat: MTLPixelFormat = .rgba8Unorm,
        depthFormat: MTLPixelFormat? = .depth32Float,
        stencilFormat: MTLPixelFormat? = nil,
        name: String = "OffscreenRenderPass"
    ) -> RenderPass? {
        guard
            let colorTexture = Texture.createRenderTarget(
                device: device,
                width: width,
                height: height,
                pixelFormat: colorFormat,
                label: "\(name)_Color"
            )
        else {
            Log.error("Failed to create color texture for offscreen render pass")
            return nil
        }

        let renderPass = RenderPass(device: device, name: name)

        renderPass.setColorAttachment(
            texture: colorTexture,
            loadAction: .clear,
            storeAction: .store
        )

        if let depthFormat = depthFormat {
            guard
                let depthTexture = Texture.createDepthTexture(
                    device: device,
                    width: width,
                    height: height,
                    pixelFormat: depthFormat,
                    label: "\(name)_Depth"
                )
            else {
                Log.warning("Failed to create depth texture for offscreen render pass")
                return renderPass
            }

            renderPass.setDepthAttachment(
                texture: depthTexture,
                loadAction: .clear,
                storeAction: .dontCare
            )
        }

        if let stencilFormat = stencilFormat {
            if stencilFormat == .depth32Float_stencil8 {
                if let depthStencilTexture = Texture.createDepthStencilTexture(
                    device: device,
                    width: width,
                    height: height,
                    label: "\(name)_DepthStencil"
                ) {
                    renderPass.setDepthStencilAttachment(
                        texture: depthStencilTexture,
                        depthLoadAction: .clear,
                        stencilLoadAction: .clear
                    )
                }
            } else {
                guard
                    let stencilTexture = Texture.createStencilTexture(
                        device: device,
                        width: width,
                        height: height,
                        pixelFormat: stencilFormat,
                        label: "\(name)_Stencil"
                    )
                else {
                    Log.warning("Failed to create stencil texture for offscreen render pass")
                    return renderPass
                }

                renderPass.setStencilAttachment(
                    texture: stencilTexture,
                    loadAction: .clear,
                    storeAction: .dontCare
                )
            }
        }

        return renderPass
    }

    // NOTE: Factory method for MSAA render passes
    public static func createMultisample(
        device: MTLDevice,
        width: Int,
        height: Int,
        sampleCount: Int = 4,
        colorFormat: MTLPixelFormat = .rgba8Unorm,
        depthFormat: MTLPixelFormat? = .depth32Float,
        name: String = "MultisampleRenderPass"
    ) -> RenderPass? {
        guard
            let msaaTexture = Texture.createMultisampleRenderTarget(
                device: device,
                width: width,
                height: height,
                pixelFormat: colorFormat,
                sampleCount: sampleCount,
                label: "\(name)_MSAA"
            )
        else {
            Log.error("Failed to create MSAA texture for multisample render pass")
            return nil
        }

        guard
            let resolveTexture = Texture.createRenderTarget(
                device: device,
                width: width,
                height: height,
                pixelFormat: colorFormat,
                label: "\(name)_Resolve"
            )
        else {
            Log.error("Failed to create resolve texture for multisample render pass")
            return nil
        }

        let renderPass = RenderPass(device: device, name: name)

        renderPass.setColorAttachment(
            texture: msaaTexture,
            loadAction: .clear,
            storeAction: .multisampleResolve
        )
        renderPass.setResolveTexture(texture: resolveTexture)

        if let depthFormat = depthFormat {
            guard
                let depthTexture = Texture.createDepthTexture(
                    device: device,
                    width: width,
                    height: height,
                    pixelFormat: depthFormat,
                    label: "\(name)_Depth"
                )
            else {
                Log.warning("Failed to create depth texture for multisample render pass")
                return renderPass
            }

            var config = depthTexture.config
            config.sampleCount = sampleCount

            if let msaaDepthTexture = Texture.createEmpty(device: device, config: config) {
                renderPass.setDepthAttachment(
                    texture: msaaDepthTexture,
                    loadAction: .clear,
                    storeAction: .dontCare
                )
            }
        }

        return renderPass
    }

    // NOTE: Specialized render pass for shadow mapping
    public static func createForShadowMapping(
        device: MTLDevice,
        width: Int = 2048,
        height: Int = 2048,
        name: String = "ShadowMapRenderPass"
    ) -> RenderPass? {
        guard
            let shadowMap = Texture.createDepthTexture(
                device: device,
                width: width,
                height: height,
                pixelFormat: .depth32Float,
                label: "\(name)_ShadowMap"
            )
        else {
            Log.error("Failed to create shadow map texture")
            return nil
        }

        let renderPass = RenderPass(device: device, name: name)

        renderPass.setDepthAttachment(
            texture: shadowMap,
            loadAction: .clear,
            storeAction: .store,
            clearDepth: 1.0
        )

        return renderPass
    }
}

