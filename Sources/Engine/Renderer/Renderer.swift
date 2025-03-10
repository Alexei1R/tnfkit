// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import MetalKit

@MainActor
public class Renderer {
    private var rendererAPI: RendererAPI!

    private var currentCamera: Camera?

    private var pipelineHandle: ResourceHandle?

    private var bufferStack: BufferStack?
    private var indexCount: Int = 0

    public init?() {
        guard let api = RendererAPI() else {
            Log.error("Failed to create RendererAPI")
            return nil
        }
        self.rendererAPI = api
        bufferStack = BufferStack(device: rendererAPI.device)

        pipelineHandle = self.createPipeline()
        createBufferStack()

    }

    func createBufferStack() {
        //QUAD

        struct Vertex {
            var position: vec3f
            var color: vec4f
        }

        let quadVertices: [Vertex] = [
            // Bottom left
            Vertex(position: vec3f(-0.5, -0.5, 0.0), color: vec4f(1.0, 0.0, 0.0, 1.0)),
            // Bottom right
            Vertex(position: vec3f(0.5, -0.5, 0.0), color: vec4f(0.0, 1.0, 0.0, 1.0)),
            // Top right
            Vertex(position: vec3f(0.5, 0.5, 0.0), color: vec4f(0.0, 0.0, 1.0, 1.0)),
            // Top left
            Vertex(position: vec3f(-0.5, 0.5, 0.0), color: vec4f(1.0, 1.0, 0.0, 1.0)),
        ]

        let quadIndices: [UInt16] = [
            0, 1, 2,
            2, 3, 0,
        ]

        indexCount = quadIndices.count

        bufferStack?.addBuffer(type: .vertex, data: quadVertices)
        bufferStack?.addBuffer(type: .index, data: quadIndices)

    }

    func createPipeline() -> ResourceHandle {

        var config = PipelineConfig(name: "Default")
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "vertex_main"),
            ShaderElement(type: .fragment, name: "fragment_main"),
        ])
        let bufferLayout = BufferLayout(elements: [
            BufferElement(type: .float3, name: "Position"),
            BufferElement(type: .float4, name: "Color"),
        ])

        config.bufferLayouts = [(bufferLayout, 0)]
        config.depthPixelFormat = .depth32Float
        config.depthWriteEnabled = true
        config.depthCompareFunction = .lessEqual
        config.blendMode = .opaque

        return rendererAPI.createPipeline(config: config)
    }

    public func addRenderable(_ renderable: Renderable) {
    }

    public func beginFrame(camera: Camera) {
        self.currentCamera = camera

    }

    public func endFrame(view: MTKView) {
        guard let rendererAPI = rendererAPI else {
            Log.error("RendererAPI is not initialized")
            return
        }
        guard let currentDrawable = view.currentDrawable else {
            Log.error("Failed to get currentDrawable")
            return
        }

        //NOTE: Main render pass
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            Log.error("Failed to get renderPassDescriptor")
            return
        }

        let commandBuffer = rendererAPI.createCommandBuffer()
        let renderEncoder = commandBuffer.beginRenderPass(descriptor: renderPassDescriptor)

        guard let pipeline = pipelineHandle?.getPipeline() else {
            Log.error("Failed to get pipeline")
            return
        }

        pipeline.bind(to: renderEncoder)
        bufferStack?.bind(encoder: renderEncoder)

        //NOTE: Draw
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: (bufferStack?.getBuffer(type: .index))!,
            indexBufferOffset: 0
        )
        commandBuffer.endActiveEncoder()
        //NOTE: End render pass

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
