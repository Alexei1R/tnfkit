// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import MetalKit

public final class StaticModel: Renderable, @unchecked Sendable {
    private var model3D: Model3D?
    private var vertexBufferHandle: Handle?
    private var indexBufferHandle: Handle?
    private var uniformBufferHandle: Handle?

    private var bufferStack: BufferStack?
    private var pipelineHandle: ResourceHandle?
    private var rendererAPI: RendererAPI?
    private var indexCount: Int = 0

    private let transformLock = NSLock()
    private var _transform: mat4f = .identity
    private var uniforms = StandardUniforms()

    public var transform: mat4f {
        get {
            transformLock.lock()
            defer { transformLock.unlock() }
            return _transform
        }
        set {
            transformLock.lock()
            _transform = newValue
            transformLock.unlock()
        }
    }

    public var isReady: Bool {
        vertexBufferHandle != nil && indexBufferHandle != nil && uniformBufferHandle != nil
            && pipelineHandle != nil && indexCount > 0
    }

    public init(modelPath: String) {
        loadModel(path: modelPath)
    }

    public func prepare(rendererAPI: RendererAPI) -> Bool {
        self.rendererAPI = rendererAPI

        // Create buffer stack
        bufferStack = BufferStack(device: rendererAPI.device, label: "Model Buffer Stack")

        // Create pipeline through RendererAPI
        pipelineHandle = createPipeline(rendererAPI: rendererAPI)

        // Load mesh data
        guard let model3D = self.model3D,
            let mesh = model3D.meshes.first,
            let meshData = model3D.extractMeshData(from: mesh)
        else {
            Log.error("Failed to extract mesh data for preparation")
            return false
        }

        // Create buffers
        vertexBufferHandle = bufferStack?.addBuffer(type: .vertex, data: meshData.vertices)
        indexBufferHandle = bufferStack?.addBuffer(type: .index, data: meshData.indices)
        indexCount = meshData.indices.count

        // Create uniform buffer
        let uniformsSize = MemoryLayout<StandardUniforms>.stride
        uniformBufferHandle = bufferStack?.createBuffer(
            type: .uniform,
            bufferSize: uniformsSize,
            options: .storageModeShared
        )

        if uniformBufferHandle == nil {
            Log.error("Failed to create uniforms buffer")
            return false
        }

        // Initialize uniforms with default values
        updateUniformBuffer()

        return isReady
    }

    private func createPipeline(rendererAPI: RendererAPI) -> ResourceHandle {
        var config = PipelineConfig(name: "Model_\(UUID().uuidString)")
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "vertex_main"),
            ShaderElement(type: .fragment, name: "fragment_main"),
        ])

        let bufferLayout = BufferLayout(elements: [
            BufferElement(type: .float3, name: "Position"),
            BufferElement(type: .float3, name: "Normal"),
            BufferElement(type: .float2, name: "TexCoords"),
            BufferElement(type: .float3, name: "Tangent"),
            BufferElement(type: .float3, name: "Bitangent"),
        ])

        config.bufferLayouts = [(bufferLayout, 0)]
        config.depthPixelFormat = .depth32Float
        config.depthWriteEnabled = true
        config.depthCompareFunction = .lessEqual
        config.blendMode = .opaque

        return rendererAPI.createPipeline(config: config)
    }

    public func update(camera: Camera, lightPosition: vec3f) {
        uniforms.modelMatrix = transform
        uniforms.viewMatrix = camera.getViewMatrix()
        uniforms.projectionMatrix = camera.getProjectionMatrix()
        uniforms.viewPosition = camera.position
        uniforms.lightPosition = lightPosition

        updateUniformBuffer()
    }

    private func updateUniformBuffer() {
        guard let bufferStack = bufferStack,
            let uniformBufferHandle = uniformBufferHandle
        else {
            return
        }

        _ = bufferStack.updateBuffer(handle: uniformBufferHandle, data: [uniforms])
    }

    public func getPipeline() -> Pipeline? {
        return pipelineHandle?.getPipeline()
    }

    public func getBufferStack() -> BufferStack? {
        return bufferStack
    }

    public func draw(renderEncoder: MTLRenderCommandEncoder) {
        guard let bufferStack = bufferStack,
            let indexBufferHandle = self.indexBufferHandle,
            let indexBuffer = bufferStack.getBuffer(handle: indexBufferHandle),
            isReady
        else { return }

        // Bind buffers
        bufferStack.bindBuffers(encoder: renderEncoder)

        // Draw indexed primitives
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }

    private func loadModel(path: String) {
        guard let filePath = Bundle.main.path(forResource: path, ofType: "usdc") else {
            Log.error("Failed to find \(path).usdc in bundle")
            return
        }

        let url = URL(fileURLWithPath: filePath)
        model3D = Model3D()

        do {
            try model3D?.load(from: url)
            Log.info("3D model loaded successfully: \(path)")
            model3D?.printModelInfo()
        } catch {
            Log.error("Failed to load 3D model: \(error)")
            model3D = nil
        }
    }
}

