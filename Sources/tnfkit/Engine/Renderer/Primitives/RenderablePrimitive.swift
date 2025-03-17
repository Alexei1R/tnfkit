// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import Metal
import simd

//NOTE: Core protocol for renderable objects
public protocol RenderablePrimitive {
    // Core rendering resources
    var pipeline: Pipeline { get }
    var bufferStack: BufferStack { get }
    var textures: [TexturePair] { get }

    // Transform properties
    var transform: mat4f { get set }

    // Geometry information
    var vertexCount: Int { get }
    var indexCount: Int { get }
    var primitiveType: MTLPrimitiveType { get }

    // Visibility control
    var isVisible: Bool { get set }

    // Core rendering methods - now with camera parameter
    func prepare(commandEncoder: MTLRenderCommandEncoder, camera: Camera)
    func render(commandEncoder: MTLRenderCommandEncoder)
    func update(deltaTime: Float)
}

public struct Uniforms {
    public var modelMatrix: mat4f
    public var viewMatrix: mat4f
    public var projectionMatrix: mat4f
    public var lightPosition: vec3f
    public var viewPosition: vec3f

    public init(
        modelMatrix: mat4f = .identity,
        viewMatrix: mat4f = .identity,
        projectionMatrix: mat4f = .identity,
        lightPosition: vec3f = vec3f(0, 5, 0),
        viewPosition: vec3f = vec3f(0, 0, 5)
    ) {
        self.modelMatrix = modelMatrix
        self.viewMatrix = viewMatrix
        self.projectionMatrix = projectionMatrix
        self.lightPosition = lightPosition
        self.viewPosition = viewPosition
    }
}

