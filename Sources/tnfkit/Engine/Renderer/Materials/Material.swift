// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import Metal
import simd

//NOTE: Defines the types of parameters that can be stored in a material
public enum MaterialParamType {
    case float
    case float2
    case float3
    case float4
    case matrix4x4
    case integer
    case boolean
    case texture(TextureContentType)

    var size: Int {
        switch self {
        case .float: return MemoryLayout<Float>.size
        case .float2: return MemoryLayout<vec2f>.size
        case .float3: return MemoryLayout<vec3f>.size
        case .float4: return MemoryLayout<vec4f>.size
        case .matrix4x4: return MemoryLayout<mat4f>.size
        case .integer: return MemoryLayout<Int32>.size
        case .boolean: return MemoryLayout<UInt32>.size
        case .texture: return 0  // Textures are not stored in the constant buffer
        }
    }

    var isBufferType: Bool {
        if case .texture = self { return false }
        return true
    }
}

//NOTE: Stores metadata and value for a single material parameter
public struct MaterialParameter {
    var type: MaterialParamType
    var offset: Int = 0
    var value: Any
    var textureHandle: Handle? = nil
    var texturePair: TexturePair? = nil
}

/// A Material class that stores PBR parameters and textures for rendering.
/// Supports automatic buffer creation and updating for GPU usage.
public class Material {
    public var name: String
    private var parameters: [String: MaterialParameter] = [:]
    private var parameterOrder: [String] = []  // Preserves insertion order for stable memory layout
    private var bufferHandle: Handle? = nil
    private var isChanged: Bool = true
    private var bufferSize: Int = 0
    private var textureParameters: [String: TexturePair] = [:]

    public init(name: String = "UnnamedMaterial") {
        self.name = name
    }

    // MARK: - Parameter Setters
    //NOTE: Methods for setting different parameter types

    @discardableResult
    public func setFloat(_ name: String, _ value: Float) -> Material {
        setParameter(name, .float, value)
        return self
    }

    @discardableResult
    public func setFloat2(_ name: String, _ value: vec2f) -> Material {
        setParameter(name, .float2, value)
        return self
    }

    @discardableResult
    public func setFloat3(_ name: String, _ value: vec3f) -> Material {
        setParameter(name, .float3, value)
        return self
    }

    @discardableResult
    public func setFloat4(_ name: String, _ value: vec4f) -> Material {
        setParameter(name, .float4, value)
        return self
    }

    @discardableResult
    public func setMatrix4x4(_ name: String, _ value: mat4f) -> Material {
        setParameter(name, .matrix4x4, value)
        return self
    }

    @discardableResult
    public func setInteger(_ name: String, _ value: Int) -> Material {
        setParameter(name, .integer, Int32(value))
        return self
    }

    @discardableResult
    public func setBoolean(_ name: String, _ value: Bool) -> Material {
        setParameter(name, .boolean, value ? UInt32(1) : UInt32(0))
        return self
    }

    //NOTE: Set a texture with its content type (albedo, normal, etc.)
    @discardableResult
    public func setTexture(_ name: String, _ texture: Texture, type: TextureContentType) -> Material
    {
        let texturePair = TexturePair(texture: texture, type: type)
        let paramType = MaterialParamType.texture(type)

        textureParameters[name] = texturePair

        if parameters[name] == nil {
            parameterOrder.append(name)
        }

        parameters[name] = MaterialParameter(
            type: paramType,
            value: type.getBidingIndex(),
            texturePair: texturePair
        )

        isChanged = true
        return self
    }

    //NOTE: Set a texture using a handle to an existing GPU texture
    @discardableResult
    public func setTextureHandle(_ name: String, _ handle: Handle, type: TextureContentType)
        -> Material
    {
        let paramType = MaterialParamType.texture(type)

        if parameters[name] == nil {
            parameterOrder.append(name)
        }

        parameters[name] = MaterialParameter(
            type: paramType,
            value: type.getBidingIndex(),
            textureHandle: handle
        )

        isChanged = true
        return self
    }

    // MARK: - Parameter Management

    //NOTE: Core method for setting parameters with proper memory layout tracking
    private func setParameter(_ name: String, _ type: MaterialParamType, _ value: Any) {
        if parameters[name] == nil {
            parameterOrder.append(name)
            recalculateLayout()
        }

        var offset = 0
        if type.isBufferType {
            if let param = parameters[name] {
                offset = param.offset
            } else {
                recalculateLayout()
                if let param = parameters[name] {
                    offset = param.offset
                }
            }
        }

        parameters[name] = MaterialParameter(type: type, offset: offset, value: value)
        isChanged = true
    }

    //NOTE: Get parameter value by name
    public func getParameter(_ name: String) -> Any? {
        return parameters[name]?.value
    }

    //NOTE: Remove parameter and update memory layout
    public func removeParameter(_ name: String) {
        guard let param = parameters[name] else { return }

        parameters.removeValue(forKey: name)
        if let index = parameterOrder.firstIndex(of: name) {
            parameterOrder.remove(at: index)
        }

        if case .texture = param.type {
            textureParameters.removeValue(forKey: name)
        }

        recalculateLayout()
        isChanged = true
    }

    // MARK: - Buffer Management

    //NOTE: Calculate memory offsets for all buffer parameters
    private func recalculateLayout() {
        var currentOffset = 0
        bufferSize = 0

        for name in parameterOrder {
            guard let param = parameters[name], param.type.isBufferType else { continue }

            parameters[name] = MaterialParameter(
                type: param.type,
                offset: currentOffset,
                value: param.value,
                textureHandle: param.textureHandle,
                texturePair: param.texturePair
            )

            currentOffset += param.type.size
        }

        bufferSize = currentOffset
    }

    //NOTE: Create GPU buffer for material parameters
    @discardableResult
    public func createBuffer(in bufferStack: BufferStack) -> Handle? {
        if bufferSize == 0 {
            recalculateLayout()
        }

        if bufferSize == 0 {
            return nil  // No buffer-type parameters to create buffer for
        }

        var bytes = [UInt8](repeating: 0, count: bufferSize)
        updateBufferBytes(&bytes)

        let handle = bufferStack.addBuffer(type: .material, data: bytes)
        bufferHandle = handle
        isChanged = false

        return handle
    }

    //NOTE: Update existing GPU buffer with current parameter values
    @discardableResult
    public func updateBuffer(in bufferStack: BufferStack) -> Bool {
        // Skip if no changes
        guard isChanged else { return false }

        // Create new buffer if none exists
        guard let handle = bufferHandle else {
            createBuffer(in: bufferStack)
            return bufferHandle != nil
        }

        var bytes = [UInt8](repeating: 0, count: bufferSize)
        updateBufferBytes(&bytes)

        let result = bufferStack.updateBuffer(handle: handle, data: bytes)
        if result {
            isChanged = false
        }

        return result
    }

    //NOTE: Write all parameter values to byte buffer for GPU upload
    private func updateBufferBytes(_ bytes: inout [UInt8]) {
        for name in parameterOrder {
            guard let param = parameters[name], param.type.isBufferType else { continue }

            let offset = param.offset

            switch param.type {
            case .float:
                if let value = param.value as? Float {
                    writeToBytes(&bytes, value, offset)
                }

            case .float2:
                if let value = param.value as? vec2f {
                    writeToBytes(&bytes, value, offset)
                }

            case .float3:
                if let value = param.value as? vec3f {
                    writeToBytes(&bytes, value, offset)
                }

            case .float4:
                if let value = param.value as? vec4f {
                    writeToBytes(&bytes, value, offset)
                }

            case .matrix4x4:
                if let value = param.value as? mat4f {
                    writeToBytes(&bytes, value, offset)
                }

            case .integer:
                if let value = param.value as? Int32 {
                    writeToBytes(&bytes, value, offset)
                }

            case .boolean:
                if let value = param.value as? UInt32 {
                    writeToBytes(&bytes, value, offset)
                }

            case .texture:
                break  // Textures are not stored in the constant buffer
            }
        }
    }

    //NOTE: Helper for writing generic value types to byte buffer
    private func writeToBytes<T>(_ bytes: inout [UInt8], _ value: T, _ offset: Int) {
        withUnsafeBytes(of: value) { buffer in
            for i in 0..<buffer.count {
                if offset + i < bytes.count {
                    bytes[offset + i] = buffer[i]
                }
            }
        }
    }

    // MARK: - Resource Access

    //NOTE: Get handle to GPU buffer
    public func getBufferHandle() -> Handle? {
        return bufferHandle
    }

    //NOTE: Get all texture pairs for rendering
    public func getTexturePairs() -> [TexturePair] {
        var textures: [TexturePair] = []

        for (_, param) in parameters {
            if case .texture = param.type, let pair = param.texturePair {
                textures.append(pair)
            }
        }

        return textures
    }

    //NOTE: Get names of all texture parameters
    public func getTextureParameterNames() -> [String] {
        return parameterOrder.filter { name in
            if let param = parameters[name], case .texture = param.type {
                return true
            }
            return false
        }
    }

    //NOTE: Get handles of all textures
    public func getTextureHandles() -> [Handle] {
        var handles: [Handle] = []

        for (_, param) in parameters {
            if case .texture = param.type, let handle = param.textureHandle {
                handles.append(handle)
            }
        }

        return handles
    }

    //NOTE: Check if material needs updating
    public func hasChanged() -> Bool {
        return isChanged
    }

    //NOTE: Mark material as changed to trigger update
    public func markChanged() {
        isChanged = true
    }

    // MARK: - Factory Methods

    //NOTE: Create a default PBR material
    public static func createDefault() -> Material {
        let material = Material(name: "DefaultMaterial")
        material.setFloat4("baseColor", vec4f(1.0, 1.0, 1.0, 1.0))
        material.setFloat("roughness", 0.5)
        material.setFloat("metallic", 0.0)
        material.setFloat3("normalFactor", vec3f(1.0, 1.0, 1.0))
        material.setFloat("ambientOcclusion", 1.0)
        return material
    }

    //NOTE: Create a material with solid color
    public static func createSolidColor(color: vec4f, name: String = "SolidColorMaterial")
        -> Material
    {
        let material = Material(name: name)
        material.setFloat4("baseColor", color)
        material.setFloat("roughness", 0.5)
        material.setFloat("metallic", 0.0)
        return material
    }
}

// MARK: - BufferStack Integration

//NOTE: Extension to integrate materials with buffer system
extension BufferStack {
    //NOTE: Add material to buffer stack
    @discardableResult
    public func addMaterial(_ material: Material) -> Handle? {
        return material.createBuffer(in: self)
    }

    //NOTE: Update material in buffer stack
    @discardableResult
    public func updateMaterial(_ material: Material) -> Bool {
        return material.updateBuffer(in: self)
    }

    //NOTE: Add texture to material and buffer stack
    @discardableResult
    public func addMaterialTexture(
        _ material: Material,
        paramName: String,
        texture: Texture,
        type: TextureContentType
    ) -> Handle? {
        guard let handle = addTexture(texture.getMetalTexture()) else { return nil }
        material.setTextureHandle(paramName, handle, type: type)
        return handle
    }
}
