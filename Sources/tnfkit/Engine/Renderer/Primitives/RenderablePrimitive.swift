// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import Metal
import simd

public protocol RenderablePrimitive {
    var pipeline: Pipeline { get }
    var bufferStack: BufferStack { get }
    var textures: [TexturePair] { get }

    var transform: mat4f { get set }

    var vertexCount: Int { get }
    var indexCount: Int { get }
    var primitiveType: MTLPrimitiveType { get }

    var isVisible: Bool { get set }
    var isSelectionTool: Bool { get set }

    func prepare(commandEncoder: MTLRenderCommandEncoder, camera: Camera)
    func render(commandEncoder: MTLRenderCommandEncoder)
    func update(deltaTime: Float)

    func prepareSelection(commandEncoder: MTLRenderCommandEncoder, camera: Camera)
    func renderSelection(commandEncoder: MTLRenderCommandEncoder)
}

extension RenderablePrimitive {
    public var isSelectionTool: Bool {
        get { return false }
        set {}
    }

    public func prepareSelection(commandEncoder: MTLRenderCommandEncoder, camera: Camera) {
        // Default implementation does nothing
    }

    public func renderSelection(commandEncoder: MTLRenderCommandEncoder) {
        // Default implementation does nothing
    }
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
