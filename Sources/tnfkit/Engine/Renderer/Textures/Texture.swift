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

    // index
    func getBidingIndex() -> Int {
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
    var texture: Texture
    var type: TextureContentType
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

    // MARK: - Texture Operations

    public func setData(
        data: UnsafeRawPointer,
        bytesPerRow: Int,
        region: MTLRegion? = nil,
        mipmapLevel: Int = 0
    ) {
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
    }

    public func generateMipmaps() {
        guard config.mipmapped && texture.mipmapLevelCount > 1 else { return }

        guard let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            Log.error("Failed to create resources for mipmap generation")
            return
        }

        blitEncoder.generateMipmaps(for: texture)
        blitEncoder.endEncoding()
        commandBuffer.commit()
    }

    public func copyFrom(_ sourceTexture: Texture) {
        guard let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            Log.error("Failed to create resources for texture copy")
            return
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
    }

    // MARK: - Binding
    public func bind(to encoder: MTLRenderCommandEncoder, at index: Int, for stage: ShaderStage) {
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
    }

    public func bindCompute(to encoder: MTLComputeCommandEncoder, at index: Int) {
        encoder.setTexture(texture, index: index)

        if let sampler = samplerState {
            encoder.setSamplerState(sampler, index: index)
        }
    }

    public func getMetalTexture() -> MTLTexture {
        return texture
    }
}

