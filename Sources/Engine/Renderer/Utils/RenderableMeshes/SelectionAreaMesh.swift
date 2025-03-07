// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import MetalKit

struct SelectionVertex {
    var position: vec2f

    static func size() -> Int {
        return MemoryLayout<SelectionVertex>.stride
    }
}

public final class SelectionArea: Renderable, @unchecked Sendable {
    private var bufferStack: BufferStack?
    private var pipelineHandle: ResourceHandle?
    private var selectionPipelineHandle: ResourceHandle?  // Special pipeline for selection pass
    private var rendererAPI: RendererAPI?

    // Vertices are updated dynamically
    private var vertexBufferHandle: Handle?
    private var vertices: [SelectionVertex] = []
    private var vertexCount: Int = 0

    // Transform is required by protocol but we use a simple 2D projection
    private var _transform: mat4f = .identity
    public var transform: mat4f {
        get { _transform }
        set { _transform = newValue }
    }

    // Selection color and transparency
    private var selectionColor: vec4f = vec4f(1.0, 0.5, 0.0, 0.3)  // Semi-transparent orange
    private var highlightColor: vec4f = vec4f(1.0, 1.0, 1.0, 1.0)  // White for selection texture

    // Flag to track if selection is active and should be drawn
    public var hasSelection: Bool = false
    private var isVisible: Bool = true

    public var isReady: Bool {
        return (pipelineHandle != nil || selectionPipelineHandle != nil) && bufferStack != nil
            && vertexBufferHandle != nil
    }

    public init() {
        // Initialize with empty selection
    }

    public func prepare(rendererAPI: RendererAPI) -> Bool {
        self.rendererAPI = rendererAPI

        // Create buffer stack
        bufferStack = BufferStack(device: rendererAPI.device, label: "Selection Buffer Stack")

        // Create pipeline with transparency for normal rendering
        pipelineHandle = createPipeline(rendererAPI: rendererAPI, forSelectionPass: false)

        // Create pipeline for selection render pass with RGBA32Float format
        selectionPipelineHandle = createPipeline(rendererAPI: rendererAPI, forSelectionPass: true)

        // Create initial empty buffer (will be updated with points)
        vertexBufferHandle = bufferStack?.createBuffer(
            type: .vertex,
            bufferSize: SelectionVertex.size() * 256,  // Reserve space for lots of vertices
            options: .storageModeShared
        )

        if vertexBufferHandle == nil {
            Log.error("Failed to create vertex buffer for selection")
            return false
        }

        return true
    }

    public func updateSelectionPoints(_ points: [vec2f]) {
        guard !points.isEmpty else {
            clearSelection()
            return
        }

        hasSelection = true

        // Use triangles for selection shape
        vertices = createTriangulatedVertices(from: points)
        vertexCount = vertices.count

        // Update the vertex buffer
        updateVertexBuffer()
    }

    public func clearSelection() {
        hasSelection = false
        vertices.removeAll()
        vertexCount = 0
        updateEmptyBuffer()
    }

    // Same as clearSelection but with explicit name for selection completion
    public func completeSelection(_ points: [vec2f]) {
        // Process the final selection if needed
        if !points.isEmpty {
            Log.info("Selection completed with \(points.count) points")
            // Here you can do any processing with the completed points
            // before clearing them
        }

        // Always clear the selection when completed
        clearSelection()
    }

    private func updateEmptyBuffer() {
        if let bufferStack = bufferStack, let vertexBufferHandle = vertexBufferHandle {
            let emptyData: [SelectionVertex] = []
            _ = bufferStack.updateBuffer(handle: vertexBufferHandle, data: emptyData)
        }
    }

    private func updateVertexBuffer() {
        if let bufferStack = bufferStack, let vertexBufferHandle = vertexBufferHandle {
            let success = bufferStack.updateBuffer(handle: vertexBufferHandle, data: vertices)
            if !success {
                Log.error("Failed to update selection vertex buffer")
            }
        }
    }

    private func createTriangulatedVertices(from points: [vec2f]) -> [SelectionVertex] {
        // If we have fewer than 3 points, we can't make a proper shape
        guard points.count >= 3 else {
            return points.map { SelectionVertex(position: $0) }
        }

        var triangleVertices: [SelectionVertex] = []

        // Find approximate centroid
        var centroid = vec2f(0, 0)
        for point in points {
            centroid.x += point.x
            centroid.y += point.y
        }
        centroid.x /= Float(points.count)
        centroid.y /= Float(points.count)

        // Create triangles by connecting each pair of adjacent points to the centroid
        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]

            // Add a triangle (centroid, p1, p2)
            triangleVertices.append(SelectionVertex(position: centroid))
            triangleVertices.append(SelectionVertex(position: p1))
            triangleVertices.append(SelectionVertex(position: p2))
        }

        return triangleVertices
    }

    private func createPipeline(rendererAPI: RendererAPI, forSelectionPass: Bool) -> ResourceHandle
    {
        var config = PipelineConfig(
            name: forSelectionPass
                ? "SelectionPass_\(UUID().uuidString)" : "Selection_\(UUID().uuidString)")

        // Use simple vertex and fragment shaders for 2D rendering
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "selection_vertex"),
            ShaderElement(type: .fragment, name: "selection_fragment"),
        ])

        // Simple layout for 2D position only
        let bufferLayout = BufferLayout(elements: [
            BufferElement(type: .float2, name: "Position")
        ])

        config.bufferLayouts = [(bufferLayout, 0)]
        config.blendMode = .transparent  // Semi-transparent rendering
        config.depthWriteEnabled = false  // Don't write to depth buffer for overlay
        config.depthCompareFunction = .always  // Always draw on top

        // Important: Set the correct pixel format for the selection pass
        if forSelectionPass {
            config.colorPixelFormat = .rgba32Float  // For selection render pass
        }

        return rendererAPI.createPipeline(config: config)
    }

    public func update(camera: Camera, lightPosition: vec3f) {
        // No updates needed for selection area
    }

    public func getPipeline() -> Pipeline? {
        return pipelineHandle?.getPipeline()
    }

    public func getSelectionPipeline() -> Pipeline? {
        return selectionPipelineHandle?.getPipeline()
    }

    public func getBufferStack() -> BufferStack? {
        return bufferStack
    }

    public func draw(renderEncoder: MTLRenderCommandEncoder) {
        // Skip drawing if not visible or no selection
        guard isVisible && hasSelection,
            vertexCount > 0,
            let bufferStack = bufferStack,
            let vertexBufferHandle = self.vertexBufferHandle,
            let vertexBuffer = bufferStack.getBuffer(handle: vertexBufferHandle),
            isReady
        else { return }

        // Check if this is a selection pass render encoder
        let isSelectionPass = renderEncoder.label?.contains("SelectionPass") == true

        // Choose the right color for the current pass - using var instead of let
        var colorToUse = isSelectionPass ? highlightColor : selectionColor

        // Set the appropriate color
        let colorBufferIndex = 0
        renderEncoder.setFragmentBytes(
            &colorToUse,
            length: MemoryLayout<vec4f>.size,
            index: colorBufferIndex)

        // Bind vertex buffer
        bufferStack.bindBuffers(encoder: renderEncoder)

        // Draw as triangles
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: vertexCount
        )
    }

    // Implementation of visibility control
    public func setVisible(_ visible: Bool) {
        isVisible = visible
    }

    // Helper methods for selection state
    public func getSelectionPointCount() -> Int {
        return vertices.count > 0 ? vertices.count / 3 : 0  // Divide by 3 since we use triangles
    }

    public var isActive: Bool {
        return hasSelection && isVisible
    }
}
