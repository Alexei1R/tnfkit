// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/mit

import Core
import Foundation
import MetalKit
import ModelIO
import simd

// Error enum for model loader errors.
public enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
}

public struct StaticModelVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var textureCoordinate: SIMD2<Float>
    var tangent: SIMD3<Float>
    var bitangent: SIMD3<Float>
}

public struct MeshData {
    var vertices: [StaticModelVertex]
    var indices: [UInt32]
}

public class Model3D {
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []

    private(set) var changeCoordinateSystem: Bool = false

    let blenderToMetalMatrix: simd_float4x4 = simd_float4x4(
        columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, -1, 0, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))

    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        var offset = 0

        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride

        descriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride

        descriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<SIMD2<Float>>.stride

        descriptor.attributes[3] = MDLVertexAttribute(
            name: MDLVertexAttributeTangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride

        descriptor.attributes[4] = MDLVertexAttribute(
            name: MDLVertexAttributeBitangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride

        descriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return descriptor
    }()

    public init() {}

    public func load(from url: URL) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("no metal device available")
        }
        let allocator = MTKMeshBufferAllocator(device: device)
        asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: allocator)
        guard let asset = asset else {
            throw ModelLoaderError.failedToLoadAsset("failed to load asset")
        }
        if #available(iOS 11.0, macOS 10.13, *) {
            asset.upAxis = SIMD3<Float>(0, 1, 0)
        }
        try loadMeshes()
        Log.info("model loaded")
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
            if let attributes = mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                if !attributes.contains(where: { $0.name == MDLVertexAttributeNormal }) {
                    mesh.addNormals(
                        withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
                }
                if !attributes.contains(where: { $0.name == MDLVertexAttributeTangent }) {
                    mesh.addTangentBasis(
                        forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                        tangentAttributeNamed: MDLVertexAttributeTangent,
                        bitangentAttributeNamed: MDLVertexAttributeBitangent)
                }
            }
        }
    }

    public func extractMeshData(from mesh: MDLMesh) -> MeshData? {
        guard let vertexBuffer = mesh.vertexBuffers.first as? MDLMeshBuffer,
            let layout = mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout
        else { return nil }
        let vertexMap = vertexBuffer.map()
        let vertexData = vertexMap.bytes
        let stride = Int(layout.stride)
        var vertices = [StaticModelVertex]()
        vertices.reserveCapacity(mesh.vertexCount)
        var attributeMap = [String: (offset: Int, format: MDLVertexFormat)]()
        for attribute in mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] ?? [] {
            attributeMap[attribute.name] = (Int(attribute.offset), attribute.format)
        }
        for i in 0..<mesh.vertexCount {
            let baseAddress = vertexData.advanced(by: i * stride)
            var vertex = StaticModelVertex(
                position: SIMD3<Float>(0, 0, 0),
                normal: SIMD3<Float>(0, 0, 0),
                textureCoordinate: SIMD2<Float>(0, 0),
                tangent: SIMD3<Float>(0, 0, 0),
                bitangent: SIMD3<Float>(0, 0, 0))
            if let (offset, _) = attributeMap[MDLVertexAttributePosition] {
                let pos = baseAddress.advanced(by: offset).assumingMemoryBound(
                    to: SIMD3<Float>.self
                ).pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(pos.x, pos.y, pos.z, 1)
                    vertex.position = SIMD3<Float>(t.x, t.y, t.z) / t.w
                } else {
                    vertex.position = pos
                }
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeNormal] {
                let n = baseAddress.advanced(by: offset).assumingMemoryBound(to: SIMD3<Float>.self)
                    .pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(n.x, n.y, n.z, 0)
                    vertex.normal = normalize(SIMD3<Float>(t.x, t.y, t.z))
                } else {
                    vertex.normal = normalize(n)
                }
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeTextureCoordinate] {
                vertex.textureCoordinate =
                    baseAddress.advanced(by: offset).assumingMemoryBound(to: SIMD2<Float>.self)
                    .pointee
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeTangent] {
                let tan = baseAddress.advanced(by: offset).assumingMemoryBound(
                    to: SIMD3<Float>.self
                ).pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(tan.x, tan.y, tan.z, 0)
                    vertex.tangent = normalize(SIMD3<Float>(t.x, t.y, t.z))
                } else {
                    vertex.tangent = normalize(tan)
                }
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeBitangent] {
                let bitan = baseAddress.advanced(by: offset).assumingMemoryBound(
                    to: SIMD3<Float>.self
                ).pointee
                if changeCoordinateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(bitan.x, bitan.y, bitan.z, 0)
                    vertex.bitangent = normalize(SIMD3<Float>(t.x, t.y, t.z))
                } else {
                    vertex.bitangent = normalize(bitan)
                }
            }
            vertices.append(vertex)
        }
        var indices = [UInt32]()
        if let submeshes = mesh.submeshes as? [MDLSubmesh] {
            for submesh in submeshes {
                guard let indexBuffer = submesh.indexBuffer as? MDLMeshBuffer else { continue }
                let indexMap = indexBuffer.map()
                let indexData = indexMap.bytes
                let indexCount = submesh.indexCount
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
                    Log.error("Model3D invalid index type")
                    continue
                }
            }
        }
        guard !vertices.isEmpty, !indices.isEmpty else { return nil }
        return MeshData(vertices: vertices, indices: indices)
    }

    public func printModelInfo() {
        Log.info("\n=== Model Information ===")
        Log.info("Number of meshes: \(meshes.count)")
        for (index, mesh) in meshes.enumerated() {
            Log.info("\nMesh \(index + 1):")
            Log.info("- Vertex count: \(mesh.vertexCount)")
            Log.info("- Submesh count: \(mesh.submeshes?.count ?? 0)")
        }
    }
}
