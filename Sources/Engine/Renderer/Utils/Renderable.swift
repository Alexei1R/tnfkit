// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import MetalKit

public protocol Renderable: Sendable {
    func prepare(rendererAPI: RendererAPI) -> Bool
    func update(camera: Camera, lightPosition: vec3f)
    func draw(renderEncoder: MTLRenderCommandEncoder)
    func getPipeline() -> Pipeline?
    func getBufferStack() -> BufferStack?
    var isReady: Bool { get }
    var transform: mat4f { get set }
}

public struct StandardUniforms {
    var modelMatrix: mat4f
    var viewMatrix: mat4f
    var projectionMatrix: mat4f
    var lightPosition: vec3f
    var viewPosition: vec3f

    init() {
        modelMatrix = .identity
        viewMatrix = .identity
        projectionMatrix = .identity
        lightPosition = vec3f(5, 5, 5)
        viewPosition = vec3f(0, 0, 5)
    }
}
