// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

struct VertexSelector {
    var position: vec2f
}

public class Selector: @preconcurrency RenderablePrimitive {
    //NOTE: Protocol conformance
    public var pipeline: Pipeline
    public var bufferStack: BufferStack
    public var textures: [TexturePair] = []

    public var transform: mat4f = mat4f.identity
    public var vertexCount: Int = 4
    public var indexCount: Int = 6
    public var primitiveType: MTLPrimitiveType = .triangle
    public var isVisible: Bool = true

    //NOTE:
    private var uniformBufferHandle: Handle?
    private var toolManager: ToolManager

    public init?(device: MTLDevice, toolManager: ToolManager) {
        self.toolManager = toolManager

        bufferStack = BufferStack(device: device, label: "Selection")

        // NOTE: Create pipeline
        var config = PipelineConfig(name: "Selector")
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "vertex_main_selector"),
            ShaderElement(type: .fragment, name: "fragment_main_selector"),
        ])

        let bufferLayout = BufferLayout(elements: [
            BufferElement(type: .float2, name: "Position")
        ])

        config.bufferLayouts = [(bufferLayout, 0)]
        config.depthPixelFormat = .depth32Float
        config.depthWriteEnabled = true
        config.depthCompareFunction = .lessEqual
        config.blendMode = .transparent

        //FIXME: Remove later
        let shaderGen = ShaderGenerator(bufferStack: bufferStack, pipelineConfig: config)
        Log.warning(shaderGen.generateShader())
        //FIXME: Remove later

        guard let pipelineState = Pipeline(device: device, config: config) else {
            Log.error("Failed to create pipeline for Selector")
            return nil
        }
        self.pipeline = pipelineState

        //NOTE: Tool
        // toolManager.getActiveTool() as SelectionTool



    }

    public func prepare(commandEncoder: MTLRenderCommandEncoder, camera: Camera) {
    }

    public func render(commandEncoder: MTLRenderCommandEncoder) {
    }

    @MainActor public func update(deltaTime: Float) {

        Log.info(toolManager.getActiveTool())

    }
}
