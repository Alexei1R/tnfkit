// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import Metal
import MetalKit
import ModelIO
import QuartzCore

public enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
    case failedToLoadTexture(String)
}

public struct StaticModelVertex {
    var position: vec3f
    var normal: vec3f
    var textureCoordinate: vec2f
    var tangent: vec3f
    var bitangent: vec3f
}

public struct MeshData {
    var vertices: [StaticModelVertex]
    var indices: [UInt32]
    var material: Material?
}

public class ModelLoader {
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var changeCoordinateSystem: Bool = false
    private(set) var loadedTextures: [String: Texture] = [:]
    private(set) var device: MTLDevice?

    //NOTE: Matrix to convert from Blender's coordinate system to Metal's
    let blenderToMetalMatrix: mat4f = mat4f(
        vec4f(1, 0, 0, 0),
        vec4f(0, 0, 1, 0),
        vec4f(0, -1, 0, 0),
        vec4f(0, 0, 0, 1)
    )

    //NOTE: Vertex descriptor defining the layout of vertex attributes in memory
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        var offset = 0

        // Position attribute
        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        // Normal attribute
        descriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        // Texture coordinate attribute
        descriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec2f>.stride

        // Tangent attribute
        descriptor.attributes[3] = MDLVertexAttribute(
            name: MDLVertexAttributeTangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        // Bitangent attribute
        descriptor.attributes[4] = MDLVertexAttribute(
            name: MDLVertexAttributeBitangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        descriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return descriptor
    }()

    public init(device: MTLDevice? = nil) {
        self.device = device ?? MTLCreateSystemDefaultDevice()
    }

    //NOTE: Load a 3D model from the specified URL
    public func load(from url: URL) throws {
        guard let device = self.device ?? MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device available")
        }
        self.device = device

        let allocator = MTKMeshBufferAllocator(device: device)
        asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: allocator)

        guard let asset = asset else {
            throw ModelLoaderError.failedToLoadAsset("Failed to load asset")
        }

        if #available(iOS 11.0, macOS 10.13, *) {
            asset.upAxis = SIMD3<Float>(0, 1, 0)
        }

        try loadMeshes()
        Log.info("Model loaded successfully")
    }

    //NOTE: Extract and prepare meshes from the loaded asset
    private func loadMeshes() throws {
        guard let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh],
            !foundMeshes.isEmpty
        else {
            throw ModelLoaderError.invalidMesh
        }

        meshes = foundMeshes

        for mesh in meshes {
            mesh.transform = MDLTransform()

            // Add missing normals and tangents if needed
            if let attributes = mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                let hasNormals = attributes.contains { $0.name == MDLVertexAttributeNormal }
                let hasTangents = attributes.contains { $0.name == MDLVertexAttributeTangent }

                if !hasNormals {
                    mesh.addNormals(
                        withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
                }

                if !hasTangents {
                    mesh.addTangentBasis(
                        forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                        tangentAttributeNamed: MDLVertexAttributeTangent,
                        bitangentAttributeNamed: MDLVertexAttributeBitangent)
                }
            }
        }
    }

    //NOTE: Extract mesh data from MDLMesh into our format
    public func extractMeshData(from mesh: MDLMesh) -> MeshData? {
        guard let vertexBuffer = mesh.vertexBuffers.first as? MDLMeshBuffer,
            let layout = mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout
        else {
            return nil
        }

        let vertexMap = vertexBuffer.map()
        let vertexData = vertexMap.bytes
        let stride = Int(layout.stride)
        var vertices = [StaticModelVertex]()
        vertices.reserveCapacity(mesh.vertexCount)

        // Create a material for this mesh
        let material = extractMaterial(from: mesh)

        // Map attribute names to their offsets and formats
        var attributeMap = [String: (offset: Int, format: MDLVertexFormat)]()
        for attribute in mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] ?? [] {
            attributeMap[attribute.name] = (Int(attribute.offset), attribute.format)
        }

        // Extract each vertex
        for i in 0..<mesh.vertexCount {
            let baseAddress = vertexData.advanced(by: i * stride)
            var vertex = StaticModelVertex(
                position: .zero,
                normal: .zero,
                textureCoordinate: .zero,
                tangent: .zero,
                bitangent: .zero
            )

            // Position
            if let (offset, _) = attributeMap[MDLVertexAttributePosition] {
                let pos = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self)
                    .pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * vec4f(pos.x, pos.y, pos.z, 1)
                    vertex.position = vec3f(t.x, t.y, t.z) / t.w
                } else {
                    vertex.position = pos
                }
            }

            // Normal
            if let (offset, _) = attributeMap[MDLVertexAttributeNormal] {
                let n = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self).pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * vec4f(n.x, n.y, n.z, 0)
                    vertex.normal = normalize(vec3f(t.x, t.y, t.z))
                } else {
                    vertex.normal = normalize(n)
                }
            }

            // Texture coordinate
            if let (offset, _) = attributeMap[MDLVertexAttributeTextureCoordinate] {
                vertex.textureCoordinate =
                    baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec2f.self).pointee
            }

            // Tangent
            if let (offset, _) = attributeMap[MDLVertexAttributeTangent] {
                let tan = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self)
                    .pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * vec4f(tan.x, tan.y, tan.z, 0)
                    vertex.tangent = normalize(vec3f(t.x, t.y, t.z))
                } else {
                    vertex.tangent = normalize(tan)
                }
            }

            // Bitangent
            if let (offset, _) = attributeMap[MDLVertexAttributeBitangent] {
                let bitan = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self)
                    .pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * vec4f(bitan.x, bitan.y, bitan.z, 0)
                    vertex.bitangent = normalize(vec3f(t.x, t.y, t.z))
                } else {
                    vertex.bitangent = normalize(bitan)
                }
            }

            vertices.append(vertex)
        }

        // Extract indices
        var indices = [UInt32]()
        if let submeshes = mesh.submeshes as? [MDLSubmesh] {
            for submesh in submeshes {
                guard let indexBuffer = submesh.indexBuffer as? MDLMeshBuffer else { continue }
                let indexMap = indexBuffer.map()
                let indexData = indexMap.bytes
                let indexCount = submesh.indexCount

                // Convert indices to UInt32 regardless of original format
                switch submesh.indexType {
                case .uint32:
                    let ptr = indexData.assumingMemoryBound(to: UInt32.self)
                    indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount))
                case .uint16:
                    let ptr = indexData.assumingMemoryBound(to: UInt16.self)
                    indices.append(
                        contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount).map {
                            UInt32($0)
                        })
                case .uint8:
                    let ptr = indexData.assumingMemoryBound(to: UInt8.self)
                    indices.append(
                        contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount).map {
                            UInt32($0)
                        })
                default:
                    Log.error("Invalid index type")
                    continue
                }
            }
        }

        guard !vertices.isEmpty, !indices.isEmpty else { return nil }
        return MeshData(vertices: vertices, indices: indices, material: material)
    }

    //NOTE: Extract material data from MDLMesh
    private func extractMaterial(from mesh: MDLMesh) -> Material? {
        guard self.device != nil else {
            Log.error("No Metal device available")
            return nil
        }

        // Check if mesh has materials
        guard let submeshes = mesh.submeshes as? [MDLSubmesh],
            !submeshes.isEmpty
        else {
            return Material.createDefault()
        }

        // Get first material with a check
        var mdlMaterial: MDLMaterial? = nil
        for submesh in submeshes {
            if let material = submesh.material {
                mdlMaterial = material
                break
            }
        }

        guard let mdlMaterial = mdlMaterial else {
            return Material.createDefault()
        }

        // Create a new material with the name from the model if available
        let materialName = mdlMaterial.name.isEmpty ? "ModelMaterial" : mdlMaterial.name
        let material = Material(name: materialName)

        // Process PBR properties (base color, metallic, roughness, normal)

        // Base color
        if let baseColorProperty = mdlMaterial.property(with: MDLMaterialSemantic.baseColor) {
            if let baseColorTexture = extractTexture(
                from: baseColorProperty, type: TextureContentType.albedo)
            {
                material.setTexture("albedoMap", baseColorTexture, type: TextureContentType.albedo)
            } else if let baseColorValue = baseColorProperty.color {
                // Convert CGColor to components
                let components = baseColorValue.components ?? [1.0, 1.0, 1.0, 1.0]
                let r = Float(components.count > 0 ? components[0] : 1.0)
                let g = Float(components.count > 1 ? components[1] : 1.0)
                let b = Float(components.count > 2 ? components[2] : 1.0)
                let a = Float(components.count > 3 ? components[3] : 1.0)

                let color = vec4f(r, g, b, a)
                material.setFloat4("baseColor", color)
            }
        } else {
            material.setFloat4("baseColor", vec4f(1.0, 1.0, 1.0, 1.0))
        }

        // Metallic
        if let metallicProperty = mdlMaterial.property(with: MDLMaterialSemantic.metallic) {
            if let metallicTexture = extractTexture(
                from: metallicProperty, type: TextureContentType.metallic)
            {
                material.setTexture(
                    "metallicMap", metallicTexture, type: TextureContentType.metallic)
            } else if metallicProperty.type == .float {
                material.setFloat("metallic", Float(metallicProperty.floatValue))
            }
        } else {
            material.setFloat("metallic", 0.0)
        }

        // Roughness
        if let roughnessProperty = mdlMaterial.property(with: MDLMaterialSemantic.roughness) {
            if let roughnessTexture = extractTexture(
                from: roughnessProperty, type: TextureContentType.roughness)
            {
                material.setTexture(
                    "roughnessMap", roughnessTexture, type: TextureContentType.roughness)
            } else if roughnessProperty.type == .float {
                material.setFloat("roughness", Float(roughnessProperty.floatValue))
            }
        } else {
            material.setFloat("roughness", 0.5)
        }

        // Normal map
        if let normalProperty = mdlMaterial.property(with: MDLMaterialSemantic.tangentSpaceNormal) {
            if let normalTexture = extractTexture(
                from: normalProperty, type: TextureContentType.normal)
            {
                material.setTexture("normalMap", normalTexture, type: TextureContentType.normal)
                material.setFloat3("normalFactor", vec3f(1.0, 1.0, 1.0))
            }
        }

        // Ambient occlusion
        if let aoProperty = mdlMaterial.property(with: MDLMaterialSemantic.ambientOcclusion) {
            if let aoTexture = extractTexture(from: aoProperty, type: TextureContentType.ao) {
                material.setTexture("aoMap", aoTexture, type: TextureContentType.ao)
            } else if aoProperty.type == .float {
                material.setFloat("ambientOcclusion", Float(aoProperty.floatValue))
            }
        } else {
            material.setFloat("ambientOcclusion", 1.0)
        }

        // Emissive
        if let emissiveProperty = mdlMaterial.property(with: MDLMaterialSemantic.emission) {
            if let emissiveTexture = extractTexture(
                from: emissiveProperty, type: TextureContentType.emissive)
            {
                material.setTexture(
                    "emissiveMap", emissiveTexture, type: TextureContentType.emissive)
            } else if let emissiveColor = emissiveProperty.color {
                // Convert CGColor to components
                let components = emissiveColor.components ?? [0.0, 0.0, 0.0]
                let r = Float(components.count > 0 ? components[0] : 0.0)
                let g = Float(components.count > 1 ? components[1] : 0.0)
                let b = Float(components.count > 2 ? components[2] : 0.0)

                let color = vec3f(r, g, b)
                material.setFloat3("emissive", color)
            }
        }

        return material
    }

    //NOTE: Extract texture from MDLMaterialProperty
    private func extractTexture(from property: MDLMaterialProperty, type: TextureContentType)
        -> Texture?
    {
        guard let device = self.device else {
            Log.error("No Metal device available")
            return nil
        }

        // Check if property has a texture
        guard property.type == .string || property.type == .URL || property.type == .texture else {
            return nil
        }

        var texturePath: String?
        var textureURL: URL?

        // Get texture path or URL
        if property.type == .string {
            texturePath = property.stringValue
        } else if property.type == .URL {
            textureURL = property.urlValue
        } else if property.type == .texture {
            if let texture = property.textureSamplerValue?.texture {
                if let mdlTexture = texture as? MDLTexture {
                    // Create a descriptor for a new texture
                    var config = TextureConfig(name: "ModelTexture")
                    config.width = Int(mdlTexture.dimensions.x)
                    config.height = Int(mdlTexture.dimensions.y)
                    config.mipmapped = true
                    config.sRGB = type == TextureContentType.albedo

                    // Try to use the texture data directly if possible
                    let loader = MTKTextureLoader(device: device)

                    // Check if we have a texture URL in our material properties
                    if property.type == .URL && property.urlValue != nil {
                        let url = property.urlValue!
                        let options: [MTKTextureLoader.Option: Any] = [
                            .generateMipmaps: true,
                            .SRGB: type == TextureContentType.albedo,
                        ]

                        if let mtlTexture = try? loader.newTexture(URL: url, options: options) {
                            return Texture(
                                device: device, existingTexture: mtlTexture, config: config)
                        }
                    } else {
                        Log.warning("No URL available for texture, can't load directly")
                    }
                }
                return nil
            }
        }

        // Check if we have a valid path or URL
        if textureURL == nil && texturePath != nil {
            // Clean up the texture path by removing any trailing brackets
            let cleanPath = texturePath!.replacingOccurrences(of: "]", with: "")

            // Try to resolve relative path to URL
            if let basePath = asset?.url?.deletingLastPathComponent() {
                textureURL = basePath.appendingPathComponent(cleanPath)
            }
        }
        guard let url = textureURL else {
            return nil
        }

        // Check if we already loaded this texture
        let urlString = url.absoluteString
        if let cachedTexture = loadedTextures[urlString] {
            return cachedTexture
        }

        // First, check if the file exists at the specified URL
        if FileManager.default.fileExists(atPath: url.path) {
            if let texture = Texture.fromFile(device: device, url: url) {
                // Cache texture for reuse
                loadedTextures[urlString] = texture
                Log.info("Successfully loaded texture from direct URL: \(url.lastPathComponent)")
                return texture
            }
        }

        // Fallback 1: Try direct filename from Assets directory
        let filename = url.lastPathComponent
        let filenameWithoutExt = filename.split(separator: ".").first ?? Substring(filename)

        // Check if texture exists in Assets directory
        if let assetsURL = Bundle.main.resourceURL?.appendingPathComponent("Assets") {
            let assetPath = assetsURL.appendingPathComponent(filename).path
            if FileManager.default.fileExists(atPath: assetPath) {
                let assetURL = assetsURL.appendingPathComponent(filename)
                if let texture = Texture.fromFile(device: device, url: assetURL) {
                    // Cache texture for reuse
                    loadedTextures[urlString] = texture
                    Log.info("Successfully loaded texture from Assets directory: \(filename)")
                    return texture
                }
            }
        }

        // Fallback 2: Try to load from bundle with just the filename
        if let bundleTexture = Texture.fromBundle(device: device, name: String(filenameWithoutExt))
        {
            // Cache texture for reuse
            loadedTextures[urlString] = bundleTexture
            return bundleTexture
        }

        Log.warning("Failed to load texture: \(url.lastPathComponent)")
        return nil
    }

    //NOTE: Print model information for debugging purposes
    public func printModelInfo() {
        Log.info("=== Model Information ===")
        Log.info("Number of meshes: \(meshes.count)")
        Log.info("Number of loaded textures: \(loadedTextures.count)")

        for (index, mesh) in meshes.enumerated() {
            Log.info("Mesh \(index + 1):")
            Log.info("- Vertex count: \(mesh.vertexCount)")
            Log.info("- Submesh count: \(mesh.submeshes?.count ?? 0)")

            // Print material info if available
            if let submeshes = mesh.submeshes as? [MDLSubmesh] {
                for (subIdx, submesh) in submeshes.enumerated() {
                    if let material = submesh.material {
                        let materialName = material.name.isEmpty ? "Unnamed" : material.name
                        Log.info("  Submesh \(subIdx + 1) Material: \(materialName)")

                        // Print some material properties
                        if let baseColor = material.property(with: MDLMaterialSemantic.baseColor) {
                            if baseColor.type == .texture {
                                Log.info("    - Base Color: <texture>")
                            } else if let color = baseColor.color {
                                if let components = color.components {
                                    let r = components.count > 0 ? components[0] : 0
                                    let g = components.count > 1 ? components[1] : 0
                                    let b = components.count > 2 ? components[2] : 0
                                    let a = components.count > 3 ? components[3] : 1
                                    Log.info("    - Base Color: (\(r), \(g), \(b), \(a))")
                                }
                            }
                        }
                    }
                }
            }
        }

        // Print loaded textures
        Log.info("Loaded Textures:")
        for (url, _) in loadedTextures {
            Log.info("- \(url)")
        }
    }

    //NOTE: Enable or disable Blender to Metal coordinate system conversion
    public func enableCoordinateSystemConversion(_ enable: Bool) {
        changeCoordinateSystem = enable
    }

    //NOTE: Clear the loaded textures cache
    public func clearTextureCache() {
        loadedTextures.removeAll()
    }

    //NOTE: Preload textures from Assets directory
    public func preloadTexturesFromAssets() {
        guard let device = self.device else {
            Log.error("No Metal device available for preloading textures")
            return
        }

        // Get Assets directory URL
        guard let resourceURL = Bundle.main.resourceURL else {
            Log.error("Could not get app bundle resource URL")
            return
        }

        let assetsURL = resourceURL.appendingPathComponent("Assets")
        if !FileManager.default.fileExists(atPath: assetsURL.path) {
            Log.warning("Assets directory does not exist")
            return
        }

        do {
            // Get all files in Assets directory
            let assetFiles = try FileManager.default.contentsOfDirectory(
                at: assetsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])

            // Filter image files
            let imageExtensions = ["jpg", "jpeg", "png", "tif", "tiff", "gif"]
            let imageFiles = assetFiles.filter { file in
                if let ext = file.pathExtension.lowercased() as String?,
                    imageExtensions.contains(ext)
                {
                    return true
                }
                return false
            }

            // Preload each texture
            Log.info("Preloading \(imageFiles.count) textures from Assets directory...")
            for imageFile in imageFiles {
                let texture = Texture.fromFile(device: device, url: imageFile)
                if texture != nil {
                    // Cache the texture with both its URL string and filename
                    loadedTextures[imageFile.absoluteString] = texture
                    loadedTextures[imageFile.lastPathComponent] = texture
                    Log.info("Preloaded texture: \(imageFile.lastPathComponent)")
                } else {
                    Log.warning("Failed to preload texture: \(imageFile.lastPathComponent)")
                }
            }

            Log.info("Finished preloading textures. Loaded \(loadedTextures.count) textures.")
        } catch {
            Log.error("Error preloading textures from Assets: \(error.localizedDescription)")
        }
    }

    //NOTE: Load a specific texture from URL with caching
    public func loadTexture(from url: URL, type: TextureContentType = .albedo) -> Texture? {
        guard let device = self.device else {
            Log.error("No Metal device available")
            return nil
        }

        let urlString = url.absoluteString

        // Check if already loaded
        if let cachedTexture = loadedTextures[urlString] {
            return cachedTexture
        }

        // Load new texture
        if let texture = Texture.fromFile(device: device, url: url) {
            loadedTextures[urlString] = texture
            return texture
        }

        Log.warning("Failed to load texture: \(url.lastPathComponent)")
        return nil
    }
}

