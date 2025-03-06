// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import MetalKit

struct GridVertex {
    var position: vec3f
    var color: vec4f
    
    static func size() -> Int {
        return MemoryLayout<GridVertex>.stride
    }
}

public final class GridRenderer: Renderable, @unchecked Sendable {
    // Core properties
    private var bufferStack: BufferStack?
    private var pipelineHandle: ResourceHandle?
    private var rendererAPI: RendererAPI?
    
    // Grid properties
    private var gridSize: Float = 20.0
    private var cellSize: Float = 1.0
    private var minorCellCount: Int = 10     // Number of minor cells per major cell
    
    // Display options
    private var showYAxis: Bool = true      // Option to show/hide Y axis
    
    // Camera matrices
    private var viewMatrix: mat4f = .identity
    private var projectionMatrix: mat4f = .identity
    
    // Vertex buffers
    private var axesBufferHandle: Handle?
    private var xzPlaneBufferHandle: Handle?
    private var xzMinorPlaneBufferHandle: Handle?
    
    private var axesVertices: [GridVertex] = []
    private var xzPlaneVertices: [GridVertex] = []
    private var xzMinorPlaneVertices: [GridVertex] = []
    
    private var axesVertexCount: Int = 0
    private var xzPlaneVertexCount: Int = 0
    private var xzMinorPlaneVertexCount: Int = 0
    
    // Colors
    private var xAxisColor: vec4f = vec4f(1.0, 0.2, 0.2, 1.0)  // Red
    private var yAxisColor: vec4f = vec4f(0.2, 1.0, 0.2, 1.0)  // Green
    private var zAxisColor: vec4f = vec4f(0.2, 0.2, 1.0, 1.0)  // Blue
    private var majorGridColor: vec4f = vec4f(0.8, 0.8, 0.8, 0.6)  // Light gray
    private var minorGridColor: vec4f = vec4f(0.6, 0.6, 0.6, 0.3)  // Darker gray
    
    // Required by protocol
    private var _transform: mat4f = .identity
    public var transform: mat4f {
        get { _transform }
        set { _transform = newValue }
    }
    
    public var isReady: Bool {
        return pipelineHandle != nil && bufferStack != nil && 
               axesBufferHandle != nil && xzPlaneBufferHandle != nil
    }
    
    public init(gridSize: Float = 20.0, cellSize: Float = 1.0, minorCellCount: Int = 10, showYAxis: Bool = true) {
        self.gridSize = gridSize
        self.cellSize = cellSize
        self.minorCellCount = max(1, minorCellCount)
        self.showYAxis = showYAxis
    }
    
    public func prepare(rendererAPI: RendererAPI) -> Bool {
        self.rendererAPI = rendererAPI
        
        // Create buffer stack
        bufferStack = BufferStack(device: rendererAPI.device, label: "Grid Buffer Stack")
        
        // Create pipeline for line rendering with depth testing to draw behind objects
        pipelineHandle = createPipeline(rendererAPI: rendererAPI)
        
        // Generate grid vertices
        generateGridVertices()
        
        // Create vertex buffers - only create if they have data
        if !axesVertices.isEmpty {
            axesBufferHandle = bufferStack?.addBuffer(type: .vertex, data: axesVertices)
        }
        
        if !xzPlaneVertices.isEmpty {
            xzPlaneBufferHandle = bufferStack?.addBuffer(type: .vertex, data: xzPlaneVertices)
        }
        
        if !xzMinorPlaneVertices.isEmpty && minorCellCount > 1 {
            xzMinorPlaneBufferHandle = bufferStack?.addBuffer(type: .vertex, data: xzMinorPlaneVertices)
        }
        
        // We need at least axes and XZ plane grid
        if axesBufferHandle == nil || xzPlaneBufferHandle == nil {
            Log.error("Failed to create essential grid buffers")
            return false
        }
        
        return true
    }
    
    private func generateGridVertices() {
        // Clear previous vertices
        axesVertices.removeAll()
        xzPlaneVertices.removeAll()
        xzMinorPlaneVertices.removeAll()
        
        // Generate axes
        generateAxesVertices()
        
        // Generate XZ plane grid (horizontal)
        generateXZPlaneVertices()
        
        // Generate minor grid for XZ plane
        if minorCellCount > 1 {
            generateXZMinorPlaneVertices()
        }
        
        // Update counts
        axesVertexCount = axesVertices.count
        xzPlaneVertexCount = xzPlaneVertices.count
        xzMinorPlaneVertexCount = xzMinorPlaneVertices.count
    }
    
    private func generateAxesVertices() {
        // X-axis (Red)
        axesVertices.append(GridVertex(position: vec3f(-gridSize, 0, 0), color: xAxisColor))
        axesVertices.append(GridVertex(position: vec3f(gridSize, 0, 0), color: xAxisColor))
        
        // Y-axis (Green) - only if enabled
        if showYAxis {
            axesVertices.append(GridVertex(position: vec3f(0, -gridSize, 0), color: yAxisColor))
            axesVertices.append(GridVertex(position: vec3f(0, gridSize, 0), color: yAxisColor))
        }
        
        // Z-axis (Blue)
        axesVertices.append(GridVertex(position: vec3f(0, 0, -gridSize), color: zAxisColor))
        axesVertices.append(GridVertex(position: vec3f(0, 0, gridSize), color: zAxisColor))
    }
    
    private func generateXZPlaneVertices() {
        // Calculate grid dimensions
        let halfGrid = gridSize / 2.0
        
        // Draw the outer boundary first (the rectangle perimeter)
        // Bottom edge (along X at -Z)
        xzPlaneVertices.append(GridVertex(position: vec3f(-halfGrid, 0, -halfGrid), color: majorGridColor))
        xzPlaneVertices.append(GridVertex(position: vec3f(halfGrid, 0, -halfGrid), color: majorGridColor))
        
        // Top edge (along X at +Z)
        xzPlaneVertices.append(GridVertex(position: vec3f(-halfGrid, 0, halfGrid), color: majorGridColor))
        xzPlaneVertices.append(GridVertex(position: vec3f(halfGrid, 0, halfGrid), color: majorGridColor))
        
        // Left edge (along Z at -X)
        xzPlaneVertices.append(GridVertex(position: vec3f(-halfGrid, 0, -halfGrid), color: majorGridColor))
        xzPlaneVertices.append(GridVertex(position: vec3f(-halfGrid, 0, halfGrid), color: majorGridColor))
        
        // Right edge (along Z at +X)
        xzPlaneVertices.append(GridVertex(position: vec3f(halfGrid, 0, -halfGrid), color: majorGridColor))
        xzPlaneVertices.append(GridVertex(position: vec3f(halfGrid, 0, halfGrid), color: majorGridColor))
        
        // Calculate how many cells fit inside the grid exactly
        // We want to avoid going outside the grid bounds
        let cellCountHalf = Int(halfGrid / cellSize)
        
        // Create internal grid lines
        for i in 1...cellCountHalf {
            let pos = Float(i) * cellSize
            
            // Only add lines that are inside the grid boundary
            if pos < halfGrid {
                // Positive X direction
                xzPlaneVertices.append(GridVertex(position: vec3f(pos, 0, -halfGrid), color: majorGridColor))
                xzPlaneVertices.append(GridVertex(position: vec3f(pos, 0, halfGrid), color: majorGridColor))
                
                // Negative X direction
                xzPlaneVertices.append(GridVertex(position: vec3f(-pos, 0, -halfGrid), color: majorGridColor))
                xzPlaneVertices.append(GridVertex(position: vec3f(-pos, 0, halfGrid), color: majorGridColor))
                
                // Positive Z direction
                xzPlaneVertices.append(GridVertex(position: vec3f(-halfGrid, 0, pos), color: majorGridColor))
                xzPlaneVertices.append(GridVertex(position: vec3f(halfGrid, 0, pos), color: majorGridColor))
                
                // Negative Z direction
                xzPlaneVertices.append(GridVertex(position: vec3f(-halfGrid, 0, -pos), color: majorGridColor))
                xzPlaneVertices.append(GridVertex(position: vec3f(halfGrid, 0, -pos), color: majorGridColor))
            }
        }
    }
    
    private func generateXZMinorPlaneVertices() {
        // Skip if minor cell count is 1 (no minor cells)
        if minorCellCount <= 1 {
            return
        }
        
        let halfGrid = gridSize / 2.0
        let cellCountHalf = Int(halfGrid / cellSize)
        let minorStep = cellSize / Float(minorCellCount)
        
        // Generate minor grid lines within each major cell
        for majorIdx in -cellCountHalf...cellCountHalf {
            let majorPos = Float(majorIdx) * cellSize
            
            // Skip the last major cell that might be incomplete
            if abs(majorPos) >= halfGrid {
                continue
            }
            
            // Calculate the next major position
            let nextMajorPos = majorPos + cellSize
            
            // Only process this major cell if the next position would still be within bounds
            if nextMajorPos <= halfGrid && nextMajorPos >= -halfGrid {
                // Add minor grid lines within this major cell
                for minorIdx in 1..<minorCellCount {
                    let minorPos = majorPos + (Float(minorIdx) * minorStep)
                    
                    // Ensure minor line is inside the grid
                    if minorPos < halfGrid && minorPos > -halfGrid {
                        // Lines parallel to X-axis
                        xzMinorPlaneVertices.append(GridVertex(position: vec3f(-halfGrid, 0, minorPos), color: minorGridColor))
                        xzMinorPlaneVertices.append(GridVertex(position: vec3f(halfGrid, 0, minorPos), color: minorGridColor))
                        
                        // Lines parallel to Z-axis
                        xzMinorPlaneVertices.append(GridVertex(position: vec3f(minorPos, 0, -halfGrid), color: minorGridColor))
                        xzMinorPlaneVertices.append(GridVertex(position: vec3f(minorPos, 0, halfGrid), color: minorGridColor))
                    }
                }
            }
        }
    }
    
    private func createPipeline(rendererAPI: RendererAPI) -> ResourceHandle {
        var config = PipelineConfig(name: "Grid_\(UUID().uuidString)")
        
        config.shaderLayout = ShaderLayout(elements: [
            ShaderElement(type: .vertex, name: "grid_vertex"),
            ShaderElement(type: .fragment, name: "grid_fragment"),
        ])
        
        let bufferLayout = BufferLayout(elements: [
            BufferElement(type: .float3, name: "Position"),
            BufferElement(type: .float4, name: "Color"),
        ])
        
        config.bufferLayouts = [(bufferLayout, 0)]
        config.blendMode = .transparent
        
        // Configure depth settings to draw behind objects
        config.depthWriteEnabled = false  // Don't write to depth buffer
        config.depthCompareFunction = .lessEqual  // Draw behind objects
        
        return rendererAPI.createPipeline(config: config)
    }
    
    public func update(camera: Camera, lightPosition: vec3f) {
        // Store camera matrices for rendering
        viewMatrix = camera.getViewMatrix()
        projectionMatrix = camera.getProjectionMatrix()
    }
    
    public func getPipeline() -> Pipeline? {
        return pipelineHandle?.getPipeline()
    }
    
    public func getBufferStack() -> BufferStack? {
        return bufferStack
    }
    
    public func draw(renderEncoder: MTLRenderCommandEncoder) {
        guard isReady,
              let bufferStack = bufferStack else {
            return
        }
        
        // Pass transform matrices to shader
        var modelMatrix = transform
        renderEncoder.setVertexBytes(
            &modelMatrix,
            length: MemoryLayout<mat4f>.size,
            index: 1)
        
        // Set view matrix at index 2
        renderEncoder.setVertexBytes(
            &viewMatrix,
            length: MemoryLayout<mat4f>.size, 
            index: 2)
        
        // Set projection matrix at index 3
        renderEncoder.setVertexBytes(
            &projectionMatrix,
            length: MemoryLayout<mat4f>.size, 
            index: 3)
        
        // Draw minor grid (lowest priority)
        if let minorGridBufferHandle = xzMinorPlaneBufferHandle,
           let minorGridBuffer = bufferStack.getBuffer(handle: minorGridBufferHandle),
           xzMinorPlaneVertexCount > 0 {
            
            renderEncoder.setVertexBuffer(minorGridBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(
                type: .line,
                vertexStart: 0,
                vertexCount: xzMinorPlaneVertexCount
            )
        }
        
        // Draw major grid (medium priority)
        if let majorGridBufferHandle = xzPlaneBufferHandle,
           let majorGridBuffer = bufferStack.getBuffer(handle: majorGridBufferHandle),
           xzPlaneVertexCount > 0 {
            
            renderEncoder.setVertexBuffer(majorGridBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(
                type: .line,
                vertexStart: 0,
                vertexCount: xzPlaneVertexCount
            )
        }
        
        // Draw axes (highest priority)
        if let axesBufferHandle = axesBufferHandle,
           let axesBuffer = bufferStack.getBuffer(handle: axesBufferHandle),
           axesVertexCount > 0 {
            
            renderEncoder.setVertexBuffer(axesBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(
                type: .line,
                vertexStart: 0,
                vertexCount: axesVertexCount
            )
        }
    }
    
    // Public methods to customize grid appearance
    public func setGridSize(_ size: Float) {
        self.gridSize = size
        regenerateGrid()
    }
    
    public func setCellSize(_ size: Float) {
        self.cellSize = size
        regenerateGrid()
    }
    
    public func setMinorCellCount(_ count: Int) {
        self.minorCellCount = max(1, count)
        regenerateGrid()
    }
    
    // Toggle Y axis visibility
    public func setYAxisVisible(_ visible: Bool) {
        if showYAxis != visible {
            showYAxis = visible
            regenerateGrid()
        }
    }
    
    // Get Y axis visibility state
    public func isYAxisVisible() -> Bool {
        return showYAxis
    }
    
    private func regenerateGrid() {
        generateGridVertices()
        
        if let bufferStack = bufferStack {
            // Update axes buffer
            if let axesBufferHandle = self.axesBufferHandle, !axesVertices.isEmpty {
                _ = bufferStack.updateBuffer(handle: axesBufferHandle, data: axesVertices)
            }
            
            // Update XZ plane buffer
            if let xzPlaneBufferHandle = self.xzPlaneBufferHandle, !xzPlaneVertices.isEmpty {
                _ = bufferStack.updateBuffer(handle: xzPlaneBufferHandle, data: xzPlaneVertices)
            }
            
            // Update XZ minor plane buffer
            if let xzMinorPlaneBufferHandle = self.xzMinorPlaneBufferHandle, !xzMinorPlaneVertices.isEmpty {
                _ = bufferStack.updateBuffer(handle: xzMinorPlaneBufferHandle, data: xzMinorPlaneVertices)
            }
        }
    }
}
