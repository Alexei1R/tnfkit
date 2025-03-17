// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit
import ModelIO

// Error enum for model loader errors
public enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
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
}

public class Model3D {
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var changeCoordinateSystem: Bool = false

    //NOTE: Blender to Metal coordinate system conversion
    let blenderToMetalMatrix: mat4f = mat4f(
        vec4f(1, 0, 0, 0),
        vec4f(0, 0, 1, 0),
        vec4f(0, -1, 0, 0),
        vec4f(0, 0, 0, 1)
    )

    //NOTE: Vertex descriptor for standard static model
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        var offset = 0

        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        descriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        descriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec2f>.stride

        descriptor.attributes[3] = MDLVertexAttribute(
            name: MDLVertexAttributeTangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        descriptor.attributes[4] = MDLVertexAttribute(
            name: MDLVertexAttributeBitangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride

        descriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return descriptor
    }()

    public init() {}

    //NOTE: Load model from URL
    public func load(from url: URL) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device available")
        }

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

    private func loadMeshes() throws {
        guard let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh],
            !foundMeshes.isEmpty
        else {
            throw ModelLoaderError.invalidMesh
        }

        meshes = foundMeshes

        for mesh in meshes {
            mesh.transform = MDLTransform()

            // Add missing attributes if needed
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
                    Log.error("Model3D: Invalid index type")
                    continue
                }
            }
        }

        guard !vertices.isEmpty, !indices.isEmpty else { return nil }
        return MeshData(vertices: vertices, indices: indices)
    }

    //NOTE: Print model information for debugging
    public func printModelInfo() {
        Log.info("=== Model Information ===")
        Log.info("Number of meshes: \(meshes.count)")

        for (index, mesh) in meshes.enumerated() {
            Log.info("Mesh \(index + 1):")
            Log.info("- Vertex count: \(mesh.vertexCount)")
            Log.info("- Submesh count: \(mesh.submeshes?.count ?? 0)")
        }
    }

    //NOTE: Enable Blender to Metal coordinate system conversion
    public func enableCoordinateSystemConversion(_ enable: Bool) {
        changeCoordinateSystem = enable
    }
}

