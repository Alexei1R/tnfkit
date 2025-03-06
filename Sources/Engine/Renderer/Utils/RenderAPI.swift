// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Metal

public enum ResourceType {
    case buffer
    case texture
    case renderPipelineState
    case depthStencilState
    case samplerState
    case argumentEncoder
    case indirectCommandBuffer
    case pipeline
}

public class ResourceHandle: Handle, @unchecked Sendable {
    let resource: Any
    let type: ResourceType

    init(resource: Any, type: ResourceType) {
        self.resource = resource
        self.type = type
        super.init()
    }

    public func getTexture() -> MTLTexture? {
        return resource as? MTLTexture
    }

    public func getBuffer() -> MTLBuffer? {
        return resource as? MTLBuffer
    }

    public func getRenderPipelineState() -> MTLRenderPipelineState? {
        return resource as? MTLRenderPipelineState
    }

    public func getDepthStencilState() -> MTLDepthStencilState? {
        return resource as? MTLDepthStencilState
    }

    public func getSamplerState() -> MTLSamplerState? {
        return resource as? MTLSamplerState
    }

    public func getPipeline() -> Pipeline? {
        return resource as? Pipeline
    }

    public func get<T>() -> T? {
        return resource as? T
    }
}

public class RendererAPI {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    private var shaderLibrary: MTLLibrary?
    private var pipelineCache: [String: ResourceHandle] = [:]

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue()
        else {
            Log.error("Failed to create Metal device or command queue")
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
    }

    public func createCommandBuffer() -> CommandBuffer {
        return CommandBuffer(commandQueue: commandQueue)
    }

    // public func createRenderPass() -> RenderPass {
    //     return RenderPass()
    // }

    // New method to create pipelines through the Pipeline class
    public func createPipeline(config: PipelineConfig) -> ResourceHandle {
        // Check if we have this pipeline cached
        if let cached = pipelineCache[config.name] {
            return cached
        }

        // Create new pipeline
        guard let pipeline = Pipeline(device: device, config: config) else {
            Log.error("Failed to create pipeline: \(config.name)")
            fatalError("Could not create pipeline")
        }

        // Cache the pipeline
        let handle = ResourceHandle(resource: pipeline, type: .pipeline)
        pipelineCache[config.name] = handle
        return handle
    }
}
