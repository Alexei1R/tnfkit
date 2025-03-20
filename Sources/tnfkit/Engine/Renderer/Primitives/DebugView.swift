// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

struct VertexDebug {
    var position: vec3f
    var texCoord: vec2f
}

public class DebugView: RenderablePrimitive {
    public var pipeline: Pipeline
    public var bufferStack: BufferStack
    public var textures: [TexturePair] = []

    public var transform: mat4f = mat4f.identity
    public var vertexCount: Int = 4
    public var indexCount: Int = 6
    public var primitiveType: MTLPrimitiveType = .triangle
    public var isVisible: Bool = true
    public var isSelectionTool: Bool = false
    
    // Debug view specific properties
    private var vertexBufferHandle: Handle?
    private var indexBufferHandle: Handle?
    private var viewportWidth: Float = 800
    private var viewportHeight: Float = 600
    private let relativeSize: Float = 0.2 // 20% of screen size
    private let padding: Float = 10.0     // Padding from screen edges (in pixels)
    
    public init?(device: MTLDevice) {
        // Create buffer stack
        bufferStack = BufferStack(device: device, label: "DebugView")

        // Create pipeline with simple shaders
        var config = PipelineConfig(name: "DebugView")
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "vertex_main_debug"),
            ShaderElement(type: .fragment, name: "fragment_main_debug"),
        ])

        let bufferLayout = BufferLayout(elements: [
            BufferElement(type: .float3, name: "Position"),
            BufferElement(type: .float2, name: "TexCoord"),
        ])

        config.bufferLayouts = [(bufferLayout, 0)]
        config.depthPixelFormat = .depth32Float
        config.depthWriteEnabled = false  // Draw on top of everything
        config.depthCompareFunction = .always
        config.blendMode = .transparent

        guard let pipelineState = Pipeline(device: device, config: config) else {
            Log.error("Failed to create pipeline for DebugView")
            return nil
        }
        self.pipeline = pipelineState

        // Create initial geometry (will be updated with correct size)
        createGeometry()
    }
    
    private func createGeometry() {
        // Initial vertices (will be updated when resize is called)
        let quadVertices: [VertexDebug] = [
            VertexDebug(position: vec3f(0.0, 0.0, 0.0), texCoord: vec2f(0.0, 1.0)),
            VertexDebug(position: vec3f(1.0, 0.0, 0.0), texCoord: vec2f(1.0, 1.0)),
            VertexDebug(position: vec3f(1.0, 1.0, 0.0), texCoord: vec2f(1.0, 0.0)),
            VertexDebug(position: vec3f(0.0, 1.0, 0.0), texCoord: vec2f(0.0, 0.0)),
        ]

        let quadIndices: [UInt16] = [
            0, 1, 2,  // First triangle
            2, 3, 0,  // Second triangle
        ]

        // Create and store buffer handles for later updates
        vertexBufferHandle = bufferStack.addBuffer(type: .vertex, data: quadVertices)
        indexBufferHandle = bufferStack.addBuffer(type: .index, data: quadIndices)
        
        // Position in top-right corner with default size
        resize(width: viewportWidth, height: viewportHeight)
    }
    
    // Public function to resize the debug view
    public func resize(width: Float, height: Float) {
        viewportWidth = width
        viewportHeight = height
        updateQuadPosition()
    }
    
    private func updateQuadPosition() {
        // Calculate quad size (20% of screen)
        let quadWidth = viewportWidth * relativeSize
        let quadHeight = viewportHeight * relativeSize
        
        // Position in top-right corner with padding
        let right = viewportWidth - padding
        let top = padding
        let left = right - quadWidth
        let bottom = top + quadHeight
        
        // Convert to normalized device coordinates (-1 to 1)
        let ndcLeft = (left / viewportWidth) * 2.0 - 1.0
        let ndcRight = (right / viewportWidth) * 2.0 - 1.0
        let ndcTop = -((top / viewportHeight) * 2.0 - 1.0)  // Y is inverted in NDC
        let ndcBottom = -((bottom / viewportHeight) * 2.0 - 1.0)  // Y is inverted in NDC
        
        // Create vertices in NDC space
        let updatedVertices: [VertexDebug] = [
            VertexDebug(position: vec3f(ndcLeft, ndcBottom, 0.0), texCoord: vec2f(0.0, 1.0)),  // Bottom-left
            VertexDebug(position: vec3f(ndcRight, ndcBottom, 0.0), texCoord: vec2f(1.0, 1.0)), // Bottom-right
            VertexDebug(position: vec3f(ndcRight, ndcTop, 0.0), texCoord: vec2f(1.0, 0.0)),    // Top-right
            VertexDebug(position: vec3f(ndcLeft, ndcTop, 0.0), texCoord: vec2f(0.0, 0.0)),     // Top-left
        ]
        
        // Update the vertex buffer
        if let handle = vertexBufferHandle {
            _ = bufferStack.updateBuffer(handle: handle, data: updatedVertices)
        }
    }
    
    // Set a texture to display in the debug view
    public func setTexture(_ texture: Texture) {
        textures = [TexturePair(texture: texture, type: .albedo)]
    }
    
    // Set a texture with specific type for visualization
    public func setTexture(_ texture: Texture, type: TextureContentType) {
        textures = [TexturePair(texture: texture, type: type)]
    }
    
    // Set multiple textures (if needed)
    public func setTextures(_ texturePairs: [TexturePair]) {
        textures = texturePairs
    }
    
    // Convenience method to quickly set a debug texture by name
    public func setTextureFromBundle(device: MTLDevice, name: String, extension: String = "jpg") {
        if let texture = Texture.fromBundle(device: device, name: name, extension: `extension`) {
            setTexture(texture)
        }
    }

    // Implementation of RenderablePrimitive protocol
    public func prepare(commandEncoder: MTLRenderCommandEncoder, camera: Camera) {
        guard isVisible else { return }
        
        // Bind pipeline
        pipeline.bind(to: commandEncoder)
        
        // Set necessary render states
        commandEncoder.setCullMode(.none)
        
        // Bind buffers
        bufferStack.bind(encoder: commandEncoder)
        
        // Bind textures
        for texturePair in textures {
            texturePair.texture.bind(
                to: commandEncoder,
                at: texturePair.type.getBindingIndex(),
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
        // No animation or updates needed for a static debug view
    }
    
}
