// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import MetalKit

public enum ShaderStage {
    case vertex
    case fragment
    case compute
    case both
}

public enum TextureDimension {
    case texture1D
    case texture2D
    case texture3D
    case textureCube

    var mtlType: MTLTextureType {
        switch self {
        case .texture1D: return .type1D
        case .texture2D: return .type2D
        case .texture3D: return .type3D
        case .textureCube: return .typeCube
        }
    }
}

// NOTE: Texture Bindings  albedo ... most important ones
public enum TextureContentType {
    case albedo
    case normal
    case metallic
    case roughness
    case ao
    case emissive
    case height
    case selection
    case unknown

    // index - Fixed method name to match existing codebase usage
    func getBindingIndex() -> Int {
        switch self {
        case .albedo: return 0
        case .normal: return 1
        case .metallic: return 2
        case .roughness: return 3
        case .ao: return 4
        case .emissive: return 5
        case .height: return 6
        case .selection: return 7
        case .unknown: return 8
        }
    }
}

//NOTE: This is for renderable primitives
public struct TexturePair {
    public var texture: Texture
    public var type: TextureContentType
}

public struct TextureConfig {
    public var name: String
    public var textureType: TextureDimension = .texture2D
    public var pixelFormat: MTLPixelFormat = .rgba8Unorm
    public var width: Int = 1
    public var height: Int = 1
    public var depth: Int = 1
    public var mipmapped: Bool = false
    public var sampleCount: Int = 1
    public var sRGB: Bool = false
    public var usage: MTLTextureUsage = [.shaderRead]
    public var storageMode: MTLStorageMode = .shared

    public init(name: String) {
        self.name = name
    }
}

public final class Texture {
    public let texture: MTLTexture
    public let config: TextureConfig
    private let device: MTLDevice
    private var samplerState: MTLSamplerState?

    public init?(device: MTLDevice, config: TextureConfig) {
        self.device = device
        self.config = config

        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = config.textureType.mtlType
        descriptor.pixelFormat = config.pixelFormat
        descriptor.width = config.width
        descriptor.height = config.height
        descriptor.depth = config.depth

        //NOTE: Calculate mipmap levels if requested
        if config.mipmapped {
            let maxDimension = max(config.width, config.height, config.depth)
            let mipLevels = Int(log2(Double(maxDimension))) + 1
            descriptor.mipmapLevelCount = mipLevels
        } else {
            descriptor.mipmapLevelCount = 1
        }

        descriptor.sampleCount = config.sampleCount
        descriptor.storageMode = config.storageMode
        descriptor.usage = config.usage

        if config.sRGB {
            switch config.pixelFormat {
            case .rgba8Unorm: descriptor.pixelFormat = .rgba8Unorm_srgb
            case .bgra8Unorm: descriptor.pixelFormat = .bgra8Unorm_srgb
            default: break
            }
        }

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            Log.error("Failed to create texture: \(config.name)")
            return nil
        }

        texture.label = config.name
        self.texture = texture

        createDefaultSampler()
    }

    public init(device: MTLDevice, existingTexture: MTLTexture, config: TextureConfig) {
        self.device = device
        self.config = config
        self.texture = existingTexture

        createDefaultSampler()
    }

    private func createDefaultSampler() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.mipFilter = config.mipmapped ? .linear : .notMipmapped

        // Use repeat addressing mode for better texture wrapping on 3D models
        // This is particularly important for seamless textures
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.rAddressMode = .repeat

        samplerState = device.makeSamplerState(descriptor: descriptor)
    }

    // MARK: - Factory Methods

    public static func createEmpty(device: MTLDevice, config: TextureConfig) -> Texture? {
        return Texture(device: device, config: config)
    }

    public static func fromData(
        device: MTLDevice,
        config: TextureConfig,
        data: UnsafeRawPointer,
        bytesPerRow: Int
    ) -> Texture? {
        guard let texture = Texture(device: device, config: config) else {
            return nil
        }

        texture.setData(data: data, bytesPerRow: bytesPerRow)

        if config.mipmapped {
            texture.generateMipmaps()
        }

        return texture
    }

    public static func fromFile(device: MTLDevice, url: URL) -> Texture? {
        let textureLoader = MTKTextureLoader(device: device)

        do {
            let texture = try textureLoader.newTexture(URL: url, options: nil)

            var config = TextureConfig(name: url.lastPathComponent)
            config.width = texture.width
            config.height = texture.height
            config.pixelFormat = texture.pixelFormat

            return Texture(device: device, existingTexture: texture, config: config)
        } catch {
            Log.error("Failed to load texture from file: \(error.localizedDescription)")
            return nil
        }
    }

    public static func fromBundle(device: MTLDevice, name: String, extension: String = "jpg")
        -> Texture?
    {
        let textureLoader = MTKTextureLoader(device: device)

        // Try multiple extensions if needed
        let extensions = [`extension`, "png", "jpg", "jpeg"]

        for ext in extensions {
            // Try to find in bundle first
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let texture = try textureLoader.newTexture(URL: url, options: nil)

                    var config = TextureConfig(name: "\(name).\(ext)")
                    config.width = texture.width
                    config.height = texture.height
                    config.pixelFormat = texture.pixelFormat

                    Log.info("Successfully loaded texture from bundle: \(name).\(ext)")
                    return Texture(device: device, existingTexture: texture, config: config)
                } catch {
                    Log.warning(
                        "Failed to load texture from bundle: \(name).\(ext): \(error.localizedDescription)"
                    )
                    // Continue trying other extensions
                }
            }
        }

        // Try Assets directory as a fallback
        if let assetsURL = Bundle.main.resourceURL?.appendingPathComponent("Assets") {
            for ext in extensions {
                let fileURL = assetsURL.appendingPathComponent("\(name).\(ext)")
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        let texture = try textureLoader.newTexture(URL: fileURL, options: nil)

                        var config = TextureConfig(name: "\(name).\(ext)")
                        config.width = texture.width
                        config.height = texture.height
                        config.pixelFormat = texture.pixelFormat

                        Log.info(
                            "Successfully loaded texture from Assets directory: \(name).\(ext)")
                        return Texture(device: device, existingTexture: texture, config: config)
                    } catch {
                        Log.warning(
                            "Failed to load texture from Assets directory: \(name).\(ext): \(error.localizedDescription)"
                        )
                    }
                }
            }
        }

        Log.error("Failed to find texture in bundle or Assets directory: \(name)")
        return nil
    }

    // MARK: - Render Target Factory Methods

    public static func createRenderTarget(
        device: MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .rgba8Unorm,
        label: String = "RenderTarget"
    ) -> Texture? {
        var config = TextureConfig(name: label)
        config.width = width
        config.height = height
        config.pixelFormat = pixelFormat
        config.usage = [.shaderRead, .renderTarget]

        return Texture(device: device, config: config)
    }

    public static func createDepthTexture(
        device: MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .depth32Float,
        label: String = "DepthTexture"
    ) -> Texture? {
        var config = TextureConfig(name: label)
        config.width = width
        config.height = height
        config.pixelFormat = pixelFormat
        config.usage = [.shaderRead, .renderTarget]

        return Texture(device: device, config: config)
    }

    public static func createStencilTexture(
        device: MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .stencil8,
        label: String = "StencilTexture"
    ) -> Texture? {
        var config = TextureConfig(name: label)
        config.width = width
        config.height = height
        config.pixelFormat = pixelFormat
        config.usage = [.shaderRead, .renderTarget]

        return Texture(device: device, config: config)
    }

    public static func createDepthStencilTexture(
        device: MTLDevice,
        width: Int,
        height: Int,
        label: String = "DepthStencilTexture"
    ) -> Texture? {
        var config = TextureConfig(name: label)
        config.width = width
        config.height = height

        // Platform-specific handling for depth-stencil format
        #if os(iOS) || os(tvOS)
            config.pixelFormat = .depth32Float_stencil8
        #else
            config.pixelFormat = .depth32Float_stencil8
        #endif

        config.usage = [.shaderRead, .renderTarget]

        return Texture(device: device, config: config)
    }

    public static func createMultisampleRenderTarget(
        device: MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .rgba8Unorm,
        sampleCount: Int = 4,
        label: String = "MultisampleRenderTarget"
    ) -> Texture? {
        var config = TextureConfig(name: label)
        config.width = width
        config.height = height
        config.pixelFormat = pixelFormat
        config.sampleCount = sampleCount
        config.usage = [.renderTarget]

        // Multisampled textures typically use private storage for performance
        config.storageMode = .private

        return Texture(device: device, config: config)
    }

    // MARK: - Texture Operations

    @discardableResult
    public func setData(
        data: UnsafeRawPointer,
        bytesPerRow: Int,
        region: MTLRegion? = nil,
        mipmapLevel: Int = 0
    ) -> Texture {
        let actualRegion =
            region
            ?? MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: config.width, height: config.height, depth: 1)
            )

        texture.replace(
            region: actualRegion,
            mipmapLevel: mipmapLevel,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )

        return self
    }

    @discardableResult
    public func generateMipmaps() -> Texture {
        guard config.mipmapped && texture.mipmapLevelCount > 1 else { return self }

        guard let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            Log.error("Failed to create resources for mipmap generation")
            return self
        }

        blitEncoder.generateMipmaps(for: texture)
        blitEncoder.endEncoding()
        commandBuffer.commit()

        return self
    }

    @discardableResult
    public func copyFrom(_ sourceTexture: Texture) -> Texture {
        guard let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            Log.error("Failed to create resources for texture copy")
            return self
        }

        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(
            width: min(texture.width, sourceTexture.texture.width),
            height: min(texture.height, sourceTexture.texture.height),
            depth: 1
        )

        blitEncoder.copy(
            from: sourceTexture.texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: origin,
            sourceSize: size,
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: origin
        )

        blitEncoder.endEncoding()
        commandBuffer.commit()

        return self
    }

    // MARK: - Custom Sampler State

    @discardableResult
    public func setCustomSampler(
        minFilter: MTLSamplerMinMagFilter = .linear,
        magFilter: MTLSamplerMinMagFilter = .linear,
        mipFilter: MTLSamplerMipFilter = .linear,
        addressModeS: MTLSamplerAddressMode = .repeat,
        addressModeT: MTLSamplerAddressMode = .repeat,
        addressModeR: MTLSamplerAddressMode = .repeat
    ) -> Texture {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = minFilter
        descriptor.magFilter = magFilter
        descriptor.mipFilter = config.mipmapped ? mipFilter : .notMipmapped
        descriptor.sAddressMode = addressModeS
        descriptor.tAddressMode = addressModeT
        descriptor.rAddressMode = addressModeR

        samplerState = device.makeSamplerState(descriptor: descriptor)

        return self
    }

    // MARK: - Binding

    @discardableResult
    public func bind(to encoder: MTLRenderCommandEncoder, at index: Int, for stage: ShaderStage)
        -> Texture
    {
        // Bind texture and sampler in one call
        switch stage {
        case .vertex:
            encoder.setVertexTexture(texture, index: index)
            if let sampler = samplerState {
                encoder.setVertexSamplerState(sampler, index: index)
            }
        case .fragment:
            encoder.setFragmentTexture(texture, index: index)
            if let sampler = samplerState {
                encoder.setFragmentSamplerState(sampler, index: index)
            }
        case .both:
            encoder.setVertexTexture(texture, index: index)
            encoder.setFragmentTexture(texture, index: index)
            if let sampler = samplerState {
                encoder.setVertexSamplerState(sampler, index: index)
                encoder.setFragmentSamplerState(sampler, index: index)
            }
        case .compute:
            Log.warning(
                "Cannot bind to compute stage with render encoder. Use bindCompute instead.")
        }

        return self
    }

    @discardableResult
    public func bindCompute(to encoder: MTLComputeCommandEncoder, at index: Int) -> Texture {
        encoder.setTexture(texture, index: index)

        if let sampler = samplerState {
            encoder.setSamplerState(sampler, index: index)
        }

        return self
    }

    @discardableResult
    public func bindByContentType(
        to encoder: MTLRenderCommandEncoder, for stage: ShaderStage, type: TextureContentType
    ) -> Texture {
        return bind(to: encoder, at: type.getBindingIndex(), for: stage)
    }

    public func getMetalTexture() -> MTLTexture {
        return texture
    }

    // MARK: - Utility

    public func width() -> Int {
        return texture.width
    }

    public func height() -> Int {
        return texture.height
    }

    public func pixelFormat() -> MTLPixelFormat {
        return texture.pixelFormat
    }

    public func isRenderTarget() -> Bool {
        return config.usage.contains(.renderTarget)
    }

    public func isDepthTexture() -> Bool {
        #if os(iOS) || os(tvOS)
            let depthFormats: [MTLPixelFormat] = [
                .depth16Unorm,
                .depth32Float,
                .depth32Float_stencil8,
            ]
        #else
            let depthFormats: [MTLPixelFormat] = [
                .depth16Unorm,
                .depth32Float,
                .depth32Float_stencil8,
                .depth24Unorm_stencil8,
            ]
        #endif

        return depthFormats.contains(texture.pixelFormat)
    }

    public func isStencilTexture() -> Bool {
        #if os(iOS) || os(tvOS)
            let stencilFormats: [MTLPixelFormat] = [
                .stencil8,
                .depth32Float_stencil8,
            ]
        #else
            let stencilFormats: [MTLPixelFormat] = [
                .stencil8,
                .depth32Float_stencil8,
                .depth24Unorm_stencil8,
            ]
        #endif

        return stencilFormats.contains(texture.pixelFormat)
    }
}
