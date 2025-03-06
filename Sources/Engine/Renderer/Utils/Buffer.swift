// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import Metal
import MetalKit
import ModelIO

public enum BufferType: Int, CaseIterable {
    case vertex = 0
    case index = 1
    case uniform = 2
    case material = 3
    case texture = 4
    case custom = 5

    var defaultBindingIndex: Int {
        switch self {
        case .vertex: return 0
        case .index: return -1
        case .uniform: return 1
        case .material: return 2
        case .texture: return 0  // Textures use a different binding space
        case .custom: return 3
        }
    }

    var bindingPriority: Int {
        switch self {
        case .vertex: return 0
        case .index: return -1
        case .uniform: return 1
        case .material: return 2
        case .texture: return 3
        case .custom: return 4
        }
    }

    var shaderStage: String {
        switch self {
        case .vertex: return "vertex"
        case .uniform: return "both"
        case .material: return "fragment"
        case .texture: return "fragment"
        case .custom: return "both"
        case .index: return "none"
        }
    }

    var shaderTypeName: String {
        switch self {
        case .vertex: return "Vertex"
        case .uniform: return "Uniforms"
        case .material: return "Material"
        case .texture: return "Texture"
        case .custom: return "Custom"
        case .index: return "Index"
        }
    }
}

class Buffer {
    var buffer: MTLBuffer
    var type: BufferType
    var sizeBytes: Int
    var order: Int
    var texture: MTLTexture?  // Add texture property

    init(
        buffer: MTLBuffer, type: BufferType, sizeBytes: Int, order: Int, texture: MTLTexture? = nil
    ) {
        self.buffer = buffer
        self.type = type
        self.sizeBytes = sizeBytes
        self.order = order
        self.texture = texture
    }
}

public final class BufferStack {
    private var buffers: [Handle: Buffer] = [:]
    private var device: MTLDevice
    private var label: String
    private var typeOrderCounters: [BufferType: Int] = [:]

    public init(device: MTLDevice, label: String = "Default") {
        self.device = device
        self.label = label

        for type in BufferType.allCases {
            typeOrderCounters[type] = 0
        }
    }

    private func getNextOrderForType(_ type: BufferType) -> Int {
        let order = typeOrderCounters[type] ?? 0
        typeOrderCounters[type] = order + 1
        return order
    }

    @discardableResult
    public func addBuffer<Data>(type: BufferType, data: [Data], options: MTLResourceOptions = [])
        -> Handle?
    {
        let bufferSize = data.count * MemoryLayout<Data>.stride
        let handle = Handle()
        let order = getNextOrderForType(type)

        guard let buffer = device.makeBuffer(bytes: data, length: bufferSize, options: options)
        else {
            Log.error("Failed to create buffer of type \(type)")
            return nil
        }

        buffer.label = "\(label)_\(type)_\(order)"
        buffers[handle] = Buffer(buffer: buffer, type: type, sizeBytes: bufferSize, order: order)
        return handle
    }

    @discardableResult
    public func createBuffer(type: BufferType, bufferSize: Int, options: MTLResourceOptions = [])
        -> Handle?
    {
        let handle = Handle()
        let order = getNextOrderForType(type)

        guard let buffer = device.makeBuffer(length: bufferSize, options: options) else {
            Log.error("Failed to create empty buffer of type \(type)")
            return nil
        }

        buffer.label = "\(label)_\(type)_\(order)"
        buffers[handle] = Buffer(buffer: buffer, type: type, sizeBytes: bufferSize, order: order)
        return handle
    }

    @discardableResult
    public func addExistingBuffer(buffer: MTLBuffer, type: BufferType, sizeBytes: Int) -> Handle? {
        let handle = Handle()
        let order = getNextOrderForType(type)

        if buffer.label == nil {
            buffer.label = "\(label)_\(type)_\(order)"
        }

        buffers[handle] = Buffer(buffer: buffer, type: type, sizeBytes: sizeBytes, order: order)
        return handle
    }

    // Add texture directly
    @discardableResult
    public func addTexture(_ texture: MTLTexture) -> Handle? {
        let handle = Handle()
        let order = getNextOrderForType(.texture)

        // Create a 1-byte dummy buffer to maintain consistency
        guard let buffer = device.makeBuffer(length: 1, options: .storageModePrivate) else {
            Log.error("Failed to create dummy buffer for texture")
            return nil
        }

        buffer.label = "\(label)_texture_\(order)"
        buffers[handle] = Buffer(
            buffer: buffer, type: .texture, sizeBytes: 1, order: order, texture: texture)
        return handle
    }

    @discardableResult
    public func addMDLBuffer(mdlBuffer: MDLMeshBuffer, type: BufferType) -> Handle? {
        if let mtkBuffer = mdlBuffer as? MTKMeshBuffer {
            return addExistingBuffer(
                buffer: mtkBuffer.buffer, type: type, sizeBytes: mdlBuffer.length)
        } else {
            let map = mdlBuffer.map()
            let data = map.bytes
            let length = mdlBuffer.length

            guard let newBuffer = device.makeBuffer(bytes: data, length: length, options: []) else {
                Log.error("Failed to create buffer from MDLMeshBuffer")
                return nil
            }

            return addExistingBuffer(buffer: newBuffer, type: type, sizeBytes: length)
        }
    }

    public func updateBuffer<Data>(handle: Handle, data: [Data]) -> Bool {
        guard let buffer = buffers[handle] else {
            Log.warning("Trying to update non-existent buffer")
            return false
        }

        let bufferSize = min(buffer.sizeBytes, data.count * MemoryLayout<Data>.stride)
        let bufferPointer = buffer.buffer.contents()

        memcpy(bufferPointer, data, bufferSize)
        return true
    }

    public func getBuffer(handle: Handle) -> MTLBuffer? {
        return buffers[handle]?.buffer
    }

    public func getTexture(handle: Handle) -> MTLTexture? {
        return buffers[handle]?.texture
    }

    public func bindBuffers(encoder: MTLRenderCommandEncoder) {
        var typeGroups: [BufferType: [Buffer]] = [:]

        for buffer in buffers.values {
            if typeGroups[buffer.type] == nil {
                typeGroups[buffer.type] = []
            }
            typeGroups[buffer.type]?.append(buffer)
        }

        let bindableTypes = BufferType.allCases.filter { $0.bindingPriority >= 0 }
        let sortedTypes = bindableTypes.sorted { $0.bindingPriority < $1.bindingPriority }

        for type in sortedTypes {
            guard let groupBuffers = typeGroups[type], !groupBuffers.isEmpty else {
                continue
            }

            let sortedBuffers = groupBuffers.sorted { $0.order < $1.order }

            for (typeIndex, buffer) in sortedBuffers.enumerated() {
                let bindingIndex =
                    type == .texture ? typeIndex : type.defaultBindingIndex + typeIndex

                switch type {
                case .vertex:
                    encoder.setVertexBuffer(buffer.buffer, offset: 0, index: bindingIndex)
                case .uniform:
                    encoder.setVertexBuffer(buffer.buffer, offset: 0, index: bindingIndex)
                    encoder.setFragmentBuffer(buffer.buffer, offset: 0, index: bindingIndex)
                case .material:
                    encoder.setFragmentBuffer(buffer.buffer, offset: 0, index: bindingIndex)
                case .texture:
                    if let texture = buffer.texture {
                        encoder.setFragmentTexture(texture, index: bindingIndex)
                        // Also bind to vertex shader if needed
                        if type.shaderStage == "both" {
                            encoder.setVertexTexture(texture, index: bindingIndex)
                        }
                    }
                case .custom:
                    encoder.setVertexBuffer(buffer.buffer, offset: 0, index: bindingIndex)
                    encoder.setFragmentBuffer(buffer.buffer, offset: 0, index: bindingIndex)
                case .index:
                    break
                }
            }
        }
    }

    public func resetBufferOrder() {
        for type in BufferType.allCases {
            typeOrderCounters[type] = 0
        }
    }
}
