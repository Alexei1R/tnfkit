// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

public class Mesh: RenderablePrimitive {
    // RenderablePrimitive conformance properties
    public var pipeline: Pipeline
    public var bufferStack: BufferStack
    public var textures: [TexturePair] = []

    public var transform: mat4f = mat4f.identity
    public var vertexCount: Int = 0
    public var indexCount: Int = 0
    public var primitiveType: MTLPrimitiveType = .triangle
    public var isVisible: Bool = true

    // Mesh-specific properties
    private var uniformBufferHandle: Handle?
    private var material: Material?
    private var modelName: String

    public init?(device: MTLDevice, modelPath: String, withExtension: String = "usdz") {
        modelName = modelPath

        // Create buffer stack
        bufferStack = BufferStack(device: device, label: "Model-\(modelPath)")

        // Create model loader and load model
        let modelLoader = ModelLoader(device: device)

        // Check if model exists in bundle
        guard let modelURL = Bundle.main.url(forResource: modelPath, withExtension: withExtension)
        else {
            Log.error("Could not find model: \(modelPath).usdc")
            return nil
        }

        do {
            // Configure model loader for Blender models
            modelLoader.enableCoordinateSystemConversion(true)

            // Load the model
            try modelLoader.load(from: modelURL)

            // Make sure we have at least one mesh
            guard let firstMesh = modelLoader.meshes.first else {
                Log.error("Model has no meshes")
                return nil
            }

            // Extract mesh data from the model
            guard let meshData = modelLoader.extractMeshData(from: firstMesh) else {
                Log.error("Failed to extract mesh data")
                return nil
            }

            // Save material
            self.material = meshData.material

            // Create pipeline
            var config = PipelineConfig(name: "Model-\(modelPath)")
            config.shaderLayout = ShaderLayout(elements: [
                ShaderElement(type: .vertex, name: "vertex_main_model"),
                ShaderElement(type: .fragment, name: "fragment_main_model"),
            ])

            // Define vertex layout based on StaticModelVertex
            let bufferLayout = BufferLayout(elements: [
                BufferElement(type: .float3, name: "Position"),
                BufferElement(type: .float3, name: "Normal"),
                BufferElement(type: .float2, name: "TexCoord"),
                BufferElement(type: .float3, name: "Tangent"),
                BufferElement(type: .float3, name: "Bitangent"),
                BufferElement(type: .int4, name: "JointIndices"),  // Added joint indices
            ])

            config.bufferLayouts = [(bufferLayout, 0)]
            config.depthPixelFormat = .depth32Float
            config.depthWriteEnabled = true
            config.depthCompareFunction = .lessEqual
            config.blendMode = .transparent

            guard let pipelineState = Pipeline(device: device, config: config) else {
                Log.error("Failed to create pipeline for Model")
                return nil
            }
            self.pipeline = pipelineState

            // Setup geometry
            setupGeometry(device: device, meshData: meshData)

            // Load textures from material if available
            loadTexturesFromMaterial(device: device)

        } catch {
            Log.error("Failed to load model: \(error.localizedDescription)")
            return nil
        }
    }

    private func setupGeometry(device: MTLDevice, meshData: MeshData) {
        // Add vertex buffer
        bufferStack.addBuffer(type: .vertex, data: meshData.vertices)
        vertexCount = meshData.vertices.count

        // Add index buffer
        bufferStack.addBuffer(type: .index, data: meshData.indices)
        indexCount = meshData.indices.count

        // Add uniform buffer
        let uniforms = Uniforms()
        uniformBufferHandle = bufferStack.addBuffer(type: .uniform, data: [uniforms])
    }

    private func loadTexturesFromMaterial(device: MTLDevice) {
        guard let material = self.material else {
            Log.warning("No material available for model \(modelName)")
            return
        }

        // Find textures in the material's parameters
        let texturePairs = material.getTexturePairs()
        if !texturePairs.isEmpty {
            textures = texturePairs
            Log.info("Loaded \(texturePairs.count) textures from material for model \(modelName)")
        } else {
            // Create a default white texture if none exists
            var config = TextureConfig(name: "DefaultAlbedo")
            config.width = 1
            config.height = 1

            if let texture = Texture.createEmpty(device: device, config: config) {
                // Get base color from material or use white if not specified
                let baseColor: vec4f =
                    (material.getParameter("baseColor") as? vec4f) ?? vec4f(1.0, 1.0, 1.0, 1.0)

                // Create a 1x1 texture with the base color
                var pixelData = baseColor
                texture.setData(data: &pixelData, bytesPerRow: MemoryLayout<vec4f>.stride)

                textures.append(TexturePair(texture: texture, type: .albedo))
                Log.info("Created default albedo texture for model \(modelName)")
            }
        }
    }

    public func prepare(commandEncoder: MTLRenderCommandEncoder, camera: Camera) {
        guard isVisible else { return }

        // Bind pipeline
        pipeline.bind(to: commandEncoder)

        // Update transform buffer
        if let handle = uniformBufferHandle {
            let uniforms = Uniforms(
                modelMatrix: transform,
                viewMatrix: camera.getViewMatrix(),
                projectionMatrix: camera.getProjectionMatrix(),
                lightPosition: vec3f(0, 5, 0),
                viewPosition: camera.position
            )
            _ = bufferStack.updateBuffer(handle: handle, data: [uniforms])
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
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }

    public func update(deltaTime: Float) {
        // Default implementation - no animation
        // You can override this to add rotation or other animations
    }

    // Helper method to set material parameters
    public func setMaterialParameter(name: String, value: Any) {
        guard let material = self.material else { return }

        if let floatValue = value as? Float {
            material.setFloat(name, floatValue)
        } else if let float3Value = value as? vec3f {
            material.setFloat3(name, float3Value)
        } else if let float4Value = value as? vec4f {
            material.setFloat4(name, float4Value)
        }
    }

    // Set model transform
    public func setTransform(_ newTransform: mat4f) {
        transform = newTransform
    }

    // Helper to position the model
    public func setPosition(_ position: vec3f) {
        let matrix = mat4f.identity
        transform = matrix.translate(position)
    }

    // Helper to scale the model
    public func setScale(_ scale: vec3f) {
        transform = transform.scale(scale)
    }

    // Helper to rotate the model
    public func setRotation(angle: Float, axis: Axis) {
        transform = transform.rotateDegrees(angle, axis: axis)
    }
}
