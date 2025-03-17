// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

public class TexturedQuad: RenderablePrimitive {
    public var pipeline: Pipeline
    public var bufferStack: BufferStack
    public var textures: [TexturePair]
    
    public var transform: mat4f = mat4f.identity
    public var vertexCount: Int = 4
    public var indexCount: Int = 6
    public var primitiveType: MTLPrimitiveType = .triangle
    public var isVisible: Bool = true
    
    // Store buffer handles for later updates
    private var uniformBufferHandle: Handle?
    
    public init?(device: MTLDevice, texturePath: String) {
        // Create buffer stack
        bufferStack = BufferStack(device: device, label: "TexturedQuad")
        
        // Load texture
        guard let path = Bundle.main.path(forResource: texturePath, ofType: "jpg") else {
            Log.error("Could not find \(texturePath).jpg in bundle")
            return nil
        }
        
        let url = URL(fileURLWithPath: path)
        guard let texture = Texture.fromFile(device: device, url: url) else {
            Log.error("Failed to load texture: \(texturePath).jpg")
            return nil
        }
        
        self.textures = [TexturePair(texture: texture, type: .albedo)]
        
        // Create pipeline
        var config = PipelineConfig(name: "TexturedQuad")
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "vertex_main"),
            ShaderElement(type: .fragment, name: "fragment_main"),
        ])
        
        let bufferLayout = BufferLayout(elements: [
            BufferElement(type: .float3, name: "Position"),
            BufferElement(type: .float4, name: "Color"),
            BufferElement(type: .float2, name: "TexCoord"),
        ])
        
        config.bufferLayouts = [(bufferLayout, 0)]
        config.depthPixelFormat = .depth32Float
        config.depthWriteEnabled = true
        config.depthCompareFunction = .lessEqual
        config.blendMode = .transparent
        
        guard let pipelineState = Pipeline(device: device, config: config) else {
            Log.error("Failed to create pipeline for TexturedQuad")
            return nil
        }
        self.pipeline = pipelineState
        
        // Create geometry
        createGeometry()
    }
    
    private func createGeometry() {
        struct Vertex {
            var position: vec3f
            var color: vec4f
            var texCoord: vec2f
        }
        
        let quadVertices: [Vertex] = [
            Vertex(position: vec3f(-0.5, -0.5, 0.0), color: vec4f(1.0, 1.0, 1.0, 1.0), texCoord: vec2f(0.0, 1.0)),
            Vertex(position: vec3f(0.5, -0.5, 0.0), color: vec4f(1.0, 1.0, 1.0, 1.0), texCoord: vec2f(1.0, 1.0)),
            Vertex(position: vec3f(0.5, 0.5, 0.0), color: vec4f(1.0, 1.0, 1.0, 1.0), texCoord: vec2f(1.0, 0.0)),
            Vertex(position: vec3f(-0.5, 0.5, 0.0), color: vec4f(1.0, 1.0, 1.0, 1.0), texCoord: vec2f(0.0, 0.0)),
        ]
        
        let quadIndices: [UInt16] = [
            0, 1, 2,
            2, 3, 0,
        ]
        
        bufferStack.addBuffer(type: .vertex, data: quadVertices)
        bufferStack.addBuffer(type: .index, data: quadIndices)
        
        // Add uniform buffer with initial data
        var uniforms = Uniforms()
        uniformBufferHandle = bufferStack.addBuffer(type: .uniform, data: [uniforms])
    }
    
    public func prepare(commandEncoder: MTLRenderCommandEncoder, camera: Camera) {
        // Bind pipeline
        pipeline.bind(to: commandEncoder)
        
        // Update transform buffer if we have a handle
        if let handle = uniformBufferHandle {
            var uniforms = Uniforms(
                modelMatrix: transform,
                viewMatrix: camera.getViewMatrix(),
                projectionMatrix: camera.getProjectionMatrix(),
                lightPosition: vec3f(0, 5, 0),
                viewPosition: camera.position
            )
            bufferStack.updateBuffer(handle: handle, data: [uniforms])
        }
        
        // Bind buffers
        bufferStack.bind(encoder: commandEncoder)
        
        // Bind textures
        for texturePair in textures {
            texturePair.texture.bind(
                to: commandEncoder,
                at: texturePair.type.getBidingIndex(),
                for: .fragment
            )
        }
    }
    
    public func render(commandEncoder: MTLRenderCommandEncoder) {
        guard isVisible, let indexBuffer = bufferStack.getBuffer(type: .index) else { return }
        
        commandEncoder.drawIndexedPrimitives(
            type: primitiveType,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }
    
    public func update(deltaTime: Float) {
        // Animate the quad by rotating it
        transform = transform.rotateDegrees(deltaTime * 45.0, axis: .y)
    }
}
