// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT


import Core
import Foundation
import Metal
import MetalKit

// MARK: - Vertex Structure

/// Vertex structure matching the buffer layout
public struct Vertex {
    var position: vec3f
    var normal: vec3f
    var texCoords: vec2f
    var tangent: vec3f
    var bitangent: vec3f

    public init(position: vec3f, normal: vec3f, texCoords: vec2f, tangent: vec3f, bitangent: vec3f)
    {
        self.position = position
        self.normal = normal
        self.texCoords = texCoords
        self.tangent = tangent
        self.bitangent = bitangent
    }

    public static func size() -> Int {
        return MemoryLayout<Vertex>.stride
    }
}

@objc public final class SelectableModel: NSObject, Renderable, @unchecked Sendable {
    // Core model components
    private var model3D: Model3D?
    private var vertexBufferHandle: Handle?
    private var indexBufferHandle: Handle?
    private var uniformBufferHandle: Handle?
    private var selectionBufferHandle: Handle?
    private var jointColorBufferHandle: Handle?

    private var bufferStack: BufferStack?
    private var pipelineHandle: ResourceHandle?
    private var rendererAPI: RendererAPI?
    private var indexCount: Int = 0
    private var vertexCount: Int = 0

    private var meshVertices: [Any]?
    private var positions: [vec3f]?

    private var selectionStates: [UInt32] = []
    private var vertexJointIndices: [Int32] = []
    private var hasModifiedSelection: Bool = false
    private var hasModifiedJointAssignments: Bool = false

    private let transformLock = NSLock()
    private var _transform: mat4f = .identity
    private var uniforms = StandardUniforms()

    private var highlightColor: vec3f = vec3f(1.0, 0.6, 0.2)
    
    // Joint colors - predefined vibrant colors for easy identification
    private let jointColors: [vec3f] = [
        vec3f(1.0, 0.0, 0.0),   // Red
        vec3f(0.0, 1.0, 0.0),   // Green
        vec3f(0.0, 0.0, 1.0),   // Blue
        vec3f(1.0, 1.0, 0.0),   // Yellow
        vec3f(1.0, 0.0, 1.0),   // Magenta
        vec3f(0.0, 1.0, 1.0),   // Cyan
        vec3f(1.0, 0.5, 0.0),   // Orange
        vec3f(0.5, 0.0, 1.0),   // Purple
        vec3f(0.0, 0.8, 0.5),   // Teal
        vec3f(0.8, 0.3, 0.3),   // Indian Red
        vec3f(0.6, 0.8, 0.2),   // Yellowish Green
        vec3f(0.2, 0.4, 0.8),   // Steel Blue
        vec3f(0.8, 0.7, 0.3),   // Gold
        vec3f(0.7, 0.3, 0.8),   // Violet
        vec3f(0.4, 0.8, 0.8),   // Light Blue
        vec3f(0.8, 0.5, 0.2)    // Brown
    ]

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
            && selectionBufferHandle != nil && pipelineHandle != nil && indexCount > 0
    }

    public var hasSelection: Bool {
        selectionStates.contains(where: { $0 > 0 })
    }
    
    @objc public func getSelectedVertexIndices() -> [Int] {
        var indices: [Int] = []
        for (index, state) in selectionStates.enumerated() {
            if state > 0 {
                indices.append(index)
            }
        }
        return indices
    }
    
    @objc public func getTotalVertexCount() -> Int {
        return vertexCount
    }
    
    @objc public func assignJointToVertices(vertexIndices: [Int], jointIndex: Int) -> Bool {
        guard jointIndex >= 0 else {
            Log.warning("Invalid joint index: \(jointIndex)")
            return false
        }
        
        // Make sure we don't exceed our color array bounds
        let colorIndex = jointIndex % jointColors.count
        
        // Assign the joint index to each vertex
        for vertexIndex in vertexIndices {
            guard vertexIndex >= 0 && vertexIndex < vertexJointIndices.count else {
                continue
            }
            
            // Store the joint index for this vertex
            vertexJointIndices[vertexIndex] = Int32(colorIndex)
        }
        
        // Mark the joint assignments as modified so the buffer gets updated
        hasModifiedJointAssignments = true
        
        Log.info("Assigned joint \(jointIndex) to \(vertexIndices.count) vertices using color index \(colorIndex)")
        return true
    }
    
    @objc public func getJointIndexForVertex(vertexIndex: Int) -> Int {
        guard vertexIndex >= 0 && vertexIndex < vertexJointIndices.count else {
            return -1
        }
        
        return Int(vertexJointIndices[vertexIndex])
    }
    
    @objc public func clearJointAssignments() {
        // Reset all vertices to unassigned (-1)
        for i in 0..<vertexJointIndices.count {
            vertexJointIndices[i] = -1
        }
        
        hasModifiedJointAssignments = true
        Log.info("All joint assignments cleared")
    }
    
    @objc public func updateVertexPosition(index: Int, transform: matrix_float4x4) {
        guard index >= 0 && index < selectionStates.count else {
            return
        }
        
        // Process in batches to reduce log spam
        let shouldLog = index % 500 == 0
        if shouldLog {
            Log.info("Animating vertex \(index) with transform")
        }
        
        // Actually transform the vertex position if we have positions array
        if var positions = self.positions, index < positions.count {
            // Get the original position
            let originalPosition = positions[index]
            
            // Convert to vec4 for matrix multiplication
            var position4 = vec4f(originalPosition.x, originalPosition.y, originalPosition.z, 1.0)
            
            // Apply the bone transformation matrix
            position4 = transform * position4
            
            // Update the position
            positions[index] = vec3f(position4.x, position4.y, position4.z)
            
            // Store the updated positions
            self.positions = positions
            
            // Mark the vertex as modified for visualization
            selectionStates[index] = 2  // Use a different value than selection (1)
            hasModifiedSelection = true
            
            // Make sure to update the vertex buffer for rendering
            if var meshVertices = self.meshVertices as? [Vertex], index < meshVertices.count {
                // Create a copy of the vertex with the updated position
                var updatedVertex = meshVertices[index]
                updatedVertex.position = positions[index]
                meshVertices[index] = updatedVertex
                
                // Store the updated vertex array
                self.meshVertices = meshVertices
                
                // Update the vertex buffer if possible
                if let bufferStack = bufferStack, 
                   let vertexBufferHandle = vertexBufferHandle {
                    _ = bufferStack.updateBuffer(handle: vertexBufferHandle, data: meshVertices)
                }
            }
            
            // Reset the selection state after a short delay (for visualization)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                self.selectionStates[index] = 0
                self.hasModifiedSelection = true
            }
        } else {
            // Fallback to just highlighting if we can't modify the positions
            selectionStates[index] = 2  // Use a different value than selection (1)
            hasModifiedSelection = true
            
            // And reset it after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.selectionStates[index] = 0
                self.hasModifiedSelection = true
            }
        }
    }

    public init(modelPath: String) {
        super.init()
        loadModel(path: modelPath)
    }

    public func prepare(rendererAPI: RendererAPI) -> Bool {
        self.rendererAPI = rendererAPI

        bufferStack = BufferStack(
            device: rendererAPI.device, label: "Selectable Model Buffer Stack")

        pipelineHandle = createPipeline(rendererAPI: rendererAPI)

        guard let model3D = self.model3D,
            let mesh = model3D.meshes.first,
            let meshData = model3D.extractMeshData(from: mesh)
        else {
            Log.error("Failed to extract mesh data for preparation")
            return false
        }

        self.meshVertices = meshData.vertices

        self.positions = extractPositions(from: meshData.vertices)

        if self.positions == nil || self.positions?.isEmpty == true {
            Log.warning("Failed to extract vertex positions for selection")
        }

        vertexBufferHandle = bufferStack?.addBuffer(type: .vertex, data: meshData.vertices)
        indexBufferHandle = bufferStack?.addBuffer(type: .index, data: meshData.indices)
        indexCount = meshData.indices.count
        vertexCount = meshData.vertices.count

        // Create uniform buffer
        let uniformsSize = MemoryLayout<StandardUniforms>.stride
        uniformBufferHandle = bufferStack?.createBuffer(
            type: .uniform,
            bufferSize: uniformsSize,
            options: .storageModeShared
        )

        selectionStates = Array(repeating: 0, count: vertexCount)
        vertexJointIndices = Array(repeating: -1, count: vertexCount) // -1 means no joint assigned

        selectionBufferHandle = bufferStack?.addBuffer(type: .custom, data: selectionStates)
        jointColorBufferHandle = bufferStack?.addBuffer(type: .custom, data: vertexJointIndices)

        if uniformBufferHandle == nil || selectionBufferHandle == nil || jointColorBufferHandle == nil {
            Log.error("Failed to create buffers for selectable model")
            return false
        }

        // Prepare the joint colors buffer that will be passed to the shader
        let colorData = jointColors.flatMap { color -> [Float] in
            return [color.x, color.y, color.z]
        }

        Log.info("SelectableModel prepared with \(vertexCount) vertices and \(indexCount) indices")
        return isReady
    }

    private func extractPositions(from vertices: [Any]) -> [vec3f]? {
        // First, try to determine what type the vertices are by examining the first one
        if vertices.isEmpty {
            return nil
        }

        // Log the actual type for debugging
        Log.info("Vertex type is: \(type(of: vertices[0]))")

        var positions: [vec3f] = []

        // Try different extraction approaches based on the vertex type
        for vertex in vertices {
            if let positionProvider = vertex as? PositionProvider {
                // Use PositionProvider protocol if implemented
                positions.append(positionProvider.position)
            } else if let dictVertex = vertex as? [String: Any],
                let position = dictVertex["position"] as? vec3f
            {
                // Handle dictionary representation
                positions.append(position)
            } else if let mirrorObject = Mirror(reflecting: vertex).children.first(where: {
                $0.label == "position"
            }),
                let position = mirrorObject.value as? vec3f
            {
                // Use reflection as a fallback
                positions.append(position)
            } else {
                // Try to access position property using KVC if it's an NSObject subclass
                if let nsObject = vertex as? NSObject,
                    let position = nsObject.value(forKey: "position") as? vec3f
                {
                    positions.append(position)
                }
            }
        }

        // If we still couldn't extract positions, log more details about the first vertex
        if positions.isEmpty && !vertices.isEmpty {
            let firstVertex = vertices[0]
            let mirror = Mirror(reflecting: firstVertex)
            var properties = ""

            for child in mirror.children {
                if let label = child.label {
                    properties += "\(label): \(type(of: child.value)), "
                }
            }

            Log.info("Vertex structure: \(properties)")
            return nil
        }

        return positions.isEmpty ? nil : positions
    }

    private func createPipeline(rendererAPI: RendererAPI) -> ResourceHandle {
        var config = PipelineConfig(name: "SelectableModel_\(UUID().uuidString)")
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "vertex_selection"),
            ShaderElement(type: .fragment, name: "fragment_selection"),
            ShaderElement(type: .compute, name: "compute_selection"),
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

        guard let bufferStack = bufferStack,
            let uniformBufferHandle = uniformBufferHandle
        else {
            return
        }

        _ = bufferStack.updateBuffer(handle: uniformBufferHandle, data: [uniforms])

        // Update selection buffer if it has been modified
        if hasModifiedSelection, let selectionBufferHandle = selectionBufferHandle {
            _ = bufferStack.updateBuffer(handle: selectionBufferHandle, data: selectionStates)
            hasModifiedSelection = false
        }
        
        // Update joint assignment buffer if it has been modified
        if hasModifiedJointAssignments, let jointColorBufferHandle = jointColorBufferHandle {
            _ = bufferStack.updateBuffer(handle: jointColorBufferHandle, data: vertexJointIndices)
            hasModifiedJointAssignments = false
        }
    }

    public func updateSelectionFromTexture(selectionTexture: MTLTexture, camera: Camera) {
        guard let bufferStack = bufferStack,
            let selectionBufferHandle = selectionBufferHandle
        else {
            // Fallback if we don't have the required components
            fallbackSelection()
            return
        }

        // Check if we have extracted positions
        guard let positions = self.positions, !positions.isEmpty else {
            Log.warning("No vertex positions available for selection")
            fallbackSelection()
            return
        }

        // Get texture dimensions
        let textureWidth = selectionTexture.width
        let textureHeight = selectionTexture.height

        if textureWidth <= 1 || textureHeight <= 1 {
            Log.warning("Invalid selection texture dimensions: \(textureWidth) x \(textureHeight)")
            fallbackSelection()
            return
        }

        // Create a buffer to hold the texture data
        let bytesPerPixel = 16  // 4 floats (RGBA) x 4 bytes
        let bytesPerRow = bytesPerPixel * textureWidth
        let dataSize = bytesPerRow * textureHeight

        // Allocate memory for texture data
        var textureData = [Float](repeating: 0, count: textureWidth * textureHeight * 4)

        // Create a temporary buffer if needed for reading
        if let device = rendererAPI?.device,
            let tempBuffer = device.makeBuffer(length: dataSize, options: .storageModeShared)
        {
            // Create a command buffer for reading the texture
            if let commandBuffer = rendererAPI?.createCommandBuffer() {
                // Create blit encoder - not optional in your API
                let blitEncoder = commandBuffer.beginBlitPass()

                // Copy texture to buffer
                blitEncoder.copy(
                    from: selectionTexture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                    sourceSize: MTLSize(width: textureWidth, height: textureHeight, depth: 1),
                    to: tempBuffer,
                    destinationOffset: 0,
                    destinationBytesPerRow: bytesPerRow,
                    destinationBytesPerImage: dataSize
                )

                // End the blit encoder and commit
                commandBuffer.endActiveEncoder()
                commandBuffer.commitAndWait()

                // Copy data from buffer to our array
                let data = tempBuffer.contents().bindMemory(
                    to: Float.self, capacity: textureWidth * textureHeight * 4)
                for i in 0..<(textureWidth * textureHeight * 4) {
                    textureData[i] = data[i]
                }

                // Process the texture data for selection
                processSelectionFromTextureData(
                    textureData: textureData,
                    width: textureWidth,
                    height: textureHeight,
                    positions: positions,
                    camera: camera
                )

                // Update the selection buffer
                hasModifiedSelection = true
                _ = bufferStack.updateBuffer(handle: selectionBufferHandle, data: selectionStates)

                Log.info(
                    "Selection updated: \(selectionStates.filter { $0 > 0 }.count) vertices selected"
                )
                return
            }
        }

        // If we reach here, the texture reading failed
        fallbackSelection()
    }

    // Process the texture data to determine which vertices are selected
    private func processSelectionFromTextureData(
        textureData: [Float],
        width: Int,
        height: Int,
        positions: [vec3f],
        camera: Camera
    ) {
        // Reset all selections
        for i in 0..<selectionStates.count {
            selectionStates[i] = 0
        }

        // Project each vertex to screen space and check if it falls within selection area
        let viewMatrix = camera.getViewMatrix()
        let projMatrix = camera.getProjectionMatrix()
        let viewProjMatrix = projMatrix * viewMatrix
        let modelMatrix = transform

        for i in 0..<min(positions.count, selectionStates.count) {
            let position = positions[i]
            let worldPos = modelMatrix * vec4f(position, 1.0)
            var clipPos = viewProjMatrix * worldPos

            // Perform perspective division
            if abs(clipPos.w) < 0.00001 { continue }  // Avoid division by zero

            clipPos.x /= clipPos.w
            clipPos.y /= clipPos.w
            clipPos.z /= clipPos.w

            // Skip vertices outside clip space
            if clipPos.x < -1.0 || clipPos.x > 1.0 || clipPos.y < -1.0 || clipPos.y > 1.0 {
                continue
            }

            // Convert to screen coordinates (0 to width, 0 to height)
            let screenX = Int((clipPos.x + 1.0) * 0.5 * Float(width))
            let screenY = Int((1.0 - (clipPos.y + 1.0) * 0.5) * Float(height))

            // Check if in viewport bounds
            if screenX >= 0 && screenX < width && screenY >= 0 && screenY < height {
                // Calculate index into texture data
                let pixelIndex = (screenY * width + screenX) * 4

                // Check if this pixel has selection color (non-zero alpha)
                if pixelIndex + 3 < textureData.count && textureData[pixelIndex + 3] > 0.1 {
                    // Mark vertex as selected
                    selectionStates[i] = 1
                }
            }
        }
    }

    // Fallback selection method when texture reading fails
    private func fallbackSelection() {
        Log.warning("Using fallback selection method - texture reading not available")

        // For demonstration, select a random subset of vertices
        for i in 0..<min(selectionStates.count, 30) {
            if arc4random_uniform(5) == 0 {  // 1/5 chance to select
                selectionStates[i] = 1
            } else {
                selectionStates[i] = 0
            }
        }

        if let bufferStack = bufferStack, let selectionBufferHandle = selectionBufferHandle {
            hasModifiedSelection = true
            _ = bufferStack.updateBuffer(handle: selectionBufferHandle, data: selectionStates)
        }

        Log.info(
            "Selection updated (demo mode): \(selectionStates.filter { $0 > 0 }.count) vertices selected"
        )
    }

    public func clearSelection() {
        guard let bufferStack = bufferStack,
            let selectionBufferHandle = selectionBufferHandle
        else {
            return
        }

        // Reset all selection states to 0 (unselected)
        if !selectionStates.allSatisfy({ $0 == 0 }) {
            selectionStates = Array(repeating: 0, count: vertexCount)
            _ = bufferStack.updateBuffer(handle: selectionBufferHandle, data: selectionStates)
            hasModifiedSelection = false

            Log.info("Selection cleared for model")
        }
    }

    // Toggle selection state for specific vertex
    public func toggleVertexSelection(vertexIndex: Int) {
        guard vertexIndex >= 0, vertexIndex < selectionStates.count,
            let bufferStack = bufferStack,
            let selectionBufferHandle = selectionBufferHandle
        else {
            return
        }

        // Toggle selection state for this vertex
        selectionStates[vertexIndex] = selectionStates[vertexIndex] == 0 ? 1 : 0

        // Update the selection buffer
        _ = bufferStack.updateBuffer(handle: selectionBufferHandle, data: selectionStates)
        hasModifiedSelection = true
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

        // Manually set the selection buffer at index 2
        if let selectionBufferHandle = selectionBufferHandle,
            let selectionBuffer = bufferStack.getBuffer(handle: selectionBufferHandle)
        {
            renderEncoder.setVertexBuffer(selectionBuffer, offset: 0, index: 2)
            renderEncoder.setFragmentBuffer(selectionBuffer, offset: 0, index: 2)
        }
        
        // Set joint indices buffer at index 4
        if let jointColorBufferHandle = jointColorBufferHandle,
            let jointIndicesBuffer = bufferStack.getBuffer(handle: jointColorBufferHandle)
        {
            renderEncoder.setVertexBuffer(jointIndicesBuffer, offset: 0, index: 4)
            renderEncoder.setFragmentBuffer(jointIndicesBuffer, offset: 0, index: 4)
        }

        // Set highlight color as a constant for the fragment shader
        // Make sure the color is bright and vibrant
        var brightHighlightColor = self.highlightColor
        renderEncoder.setFragmentBytes(
            &brightHighlightColor,
            length: MemoryLayout<vec3f>.stride,
            index: 3
        )
        
        // Pass joint colors array to the shader
        var jointColorArray = jointColors
        renderEncoder.setFragmentBytes(
            &jointColorArray,
            length: MemoryLayout<vec3f>.stride * jointColors.count,
            index: 5
        )
        
        // Pass the number of joint colors for array bounds checking
        var jointColorCount = Int32(jointColors.count)
        renderEncoder.setFragmentBytes(
            &jointColorCount,
            length: MemoryLayout<Int32>.stride,
            index: 6
        )

        // Bind other buffers
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

// MARK: - Position Provider Protocol

/// Simple protocol for vertex position extraction
protocol PositionProvider {
    var position: vec3f { get }
}

// MARK: - ModelSelectionProcessor Class

@MainActor
public class ModelSelectionProcessor {
    private weak var renderer: Renderer?

    public init(renderer: Renderer) {
        self.renderer = renderer
    }

    /// Process a selection texture and apply it to a selectable model
    /// - Parameters:
    ///   - model: The SelectableModel to update
    ///   - camera: The camera used for rendering
    public func processSelection(model: SelectableModel, camera: Camera) {
        guard let renderer = renderer,
            let selectionTexture = renderer.getSelectionTexture()
        else {
            Log.warning("Cannot process selection - missing renderer or selection texture")
            return
        }

        // Update the model's selection state based on the texture
        model.updateSelectionFromTexture(selectionTexture: selectionTexture, camera: camera)
    }

    /// Clears the selection for a model
    public func clearSelection(model: SelectableModel) {
        model.clearSelection()
    }

    /// Apply selection to multiple models
    public func processSelectionForModels(models: [SelectableModel], camera: Camera) {
        guard let renderer = renderer,
            let selectionTexture = renderer.getSelectionTexture()
        else {
            return
        }

        for model in models {
            model.updateSelectionFromTexture(selectionTexture: selectionTexture, camera: camera)
        }

        Log.info("Selection processed for \(models.count) selectable models")
    }
}
