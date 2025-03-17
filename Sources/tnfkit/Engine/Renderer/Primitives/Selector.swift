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
    //NOTE: RenderablePrimitive conformance properties
    public var pipeline: Pipeline
    public var bufferStack: BufferStack
    public var textures: [TexturePair] = []
    public var transform: mat4f = mat4f.identity
    public var vertexCount: Int = 0
    public var indexCount: Int = 0
    public var primitiveType: MTLPrimitiveType = .triangleStrip
    public var isVisible: Bool = false
    public var isSelectable: Bool = false

    //NOTE: Selection-specific properties
    private var vertexBufferHandle: Handle?
    private var outlineBufferHandle: Handle?
    private var toolManager: ToolManager
    private var currentPoints: [vec2f] = []
    private let selectionColor: vec4f = vec4f(x: 0.2, y: 0.6, z: 1.0, w: 0.25)
    private let outlineColor: vec4f = vec4f(x: 0.0, y: 0.8, z: 1.0, w: 1.0)
    private let maxVertexCount: Int = 256
    private let maxOutlineVertices: Int = 512
    private var outlineVertexCount: Int = 0

    public init?(device: MTLDevice, toolManager: ToolManager) {
        self.toolManager = toolManager
        bufferStack = BufferStack(device: device, label: "Selection")

        //NOTE: Configure rendering pipeline
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
        config.depthWriteEnabled = false
        config.depthCompareFunction = .always
        config.blendMode = .transparent

        guard let pipelineState = Pipeline(device: device, config: config) else {
            Log.error("Failed to create pipeline for Selector")
            return nil
        }
        self.pipeline = pipelineState

        //NOTE: Create buffers for geometry
        vertexBufferHandle = bufferStack.createBuffer(
            type: .vertex,
            bufferSize: maxVertexCount * MemoryLayout<VertexSelector>.stride
        )

        outlineBufferHandle = bufferStack.createBuffer(
            type: .vertex,
            bufferSize: maxOutlineVertices * MemoryLayout<VertexSelector>.stride
        )
    }

    private var listenersInitialized = false

    public func prepare(commandEncoder: MTLRenderCommandEncoder, camera: Camera) {
        guard isVisible, vertexCount > 0,
            let vertexBufferHandle = vertexBufferHandle
        else { return }

        //NOTE: Set up rendering state
        pipeline.bind(to: commandEncoder)
        commandEncoder.setCullMode(.none)

        //NOTE: Bind vertices and set color
        if let vertBuffer = bufferStack.getBuffer(handle: vertexBufferHandle) {
            commandEncoder.setVertexBuffer(vertBuffer, offset: 0, index: 0)

            var color = selectionColor
            commandEncoder.setFragmentBytes(&color, length: MemoryLayout<vec4f>.stride, index: 0)
        }

        //NOTE: Pass parameters to shader
        var uniformValue: Float = 1.0
        commandEncoder.setVertexBytes(&uniformValue, length: MemoryLayout<Float>.stride, index: 1)
    }

    public func render(commandEncoder: MTLRenderCommandEncoder) {
        guard isVisible else { return }

        //NOTE: Draw filled area
        if vertexCount > 0 {
            commandEncoder.drawPrimitives(
                type: primitiveType,
                vertexStart: 0,
                vertexCount: vertexCount
            )
        }

        //NOTE: Draw outline
        if outlineVertexCount > 0, let outlineBufferHandle = outlineBufferHandle,
            let outlineBuffer = bufferStack.getBuffer(handle: outlineBufferHandle)
        {

            var color = outlineColor
            commandEncoder.setFragmentBytes(&color, length: MemoryLayout<vec4f>.stride, index: 0)
            commandEncoder.setVertexBuffer(outlineBuffer, offset: 0, index: 0)

            //NOTE: Draw outline multiple times for thickness
            for _ in 0..<4 {
                commandEncoder.drawPrimitives(
                    type: .lineStrip,
                    vertexStart: 0,
                    vertexCount: outlineVertexCount
                )
            }
        }
    }

    @MainActor public func update(deltaTime: Float) {
        //NOTE: Initialize listeners first time
        if !listenersInitialized {
            setupToolListener()
            listenersInitialized = true
        }

        let wasSelectable = isSelectable

        //NOTE: Check if selection tool is active
        if toolManager.isToolActive(.select),
            let selectionTool = toolManager.getTool(.select) as? SelectionTool
        {
            isSelectable = true

            //NOTE: Update selection if points changed
            let points = selectionTool.getSelectionPoints()
            if points != currentPoints {
                currentPoints = points
                updateVertexBuffer()
            }
        } else {
            isSelectable = false

            //NOTE: Clear selection when tool is inactive
            if !currentPoints.isEmpty {
                currentPoints.removeAll()
                updateVertexBuffer()
            }
        }

        if wasSelectable != isSelectable {
            Log.info("Selector isSelectable: \(isSelectable)")
        }
    }

    private func updateVertexBuffer() {
        guard let vertexBufferHandle = vertexBufferHandle,
            let outlineBufferHandle = outlineBufferHandle
        else { return }

        //NOTE: Handle empty selection
        if currentPoints.isEmpty {
            isVisible = false
            vertexCount = 0
            outlineVertexCount = 0
            return
        }

        //NOTE: Filter points that are too close together
        let minDistance: Float = 0.005
        var filteredPoints: [vec2f] = []

        for point in currentPoints {
            if filteredPoints.isEmpty {
                filteredPoints.append(point)
            } else {
                let lastPoint = filteredPoints.last!
                let dx = point.x - lastPoint.x
                let dy = point.y - lastPoint.y
                let distance = sqrt(dx * dx + dy * dy)

                if distance >= minDistance {
                    filteredPoints.append(point)
                }
            }
        }

        //NOTE: Need at least 3 points for a valid polygon
        if filteredPoints.count < 3 {
            isVisible = false
            vertexCount = 0
            outlineVertexCount = 0
            return
        }

        isVisible = true
        let ndcPoints = filteredPoints.toNDC()
        let pointCount = min(ndcPoints.count, maxVertexCount - 1)  // -1 for centroid

        //NOTE: Calculate centroid for filled area
        let centroidX = ndcPoints.reduce(0) { $0 + $1.x } / Float(ndcPoints.count)
        let centroidY = ndcPoints.reduce(0) { $0 + $1.y } / Float(ndcPoints.count)
        let centroid = vec2f(x: centroidX, y: centroidY)

        //NOTE: Create filled area vertices (triangle strip)
        var fillVertices: [VertexSelector] = []
        fillVertices.append(VertexSelector(position: centroid))

        for i in 0..<pointCount {
            fillVertices.append(VertexSelector(position: ndcPoints[i]))

            if i < pointCount - 1 {
                fillVertices.append(VertexSelector(position: centroid))
            }
        }

        if pointCount > 2 {
            fillVertices.append(VertexSelector(position: ndcPoints[0]))
        }

        //NOTE: Create outline vertices (line strip)
        var outlineVertices: [VertexSelector] = []

        for i in 0..<pointCount {
            outlineVertices.append(VertexSelector(position: ndcPoints[i]))
        }

        // Close the outline loop
        if pointCount > 0 {
            outlineVertices.append(VertexSelector(position: ndcPoints[0]))
        }

        //NOTE: Update GPU buffers
        bufferStack.updateBuffer(
            handle: vertexBufferHandle,
            data: fillVertices
        )

        bufferStack.updateBuffer(
            handle: outlineBufferHandle,
            data: outlineVertices
        )

        vertexCount = fillVertices.count
        outlineVertexCount = outlineVertices.count
    }

    @MainActor
    private func setupToolListener() {
        //NOTE: Get selection tool and configure callbacks
        guard let selectionTool = toolManager.getTool(.select) as? SelectionTool else {
            Log.error("Cannot access selection tool")
            return
        }

        //NOTE: Update selection in real-time
        selectionTool.setSelectionChangeHandler { [weak self] points in
            guard let self = self else { return }
            self.currentPoints = points
            self.updateVertexBuffer()
        }

        //NOTE: Process final selection
        selectionTool.setSelectionCompletionHandler { [weak self] points in
            guard let self = self else { return }
            Log.info("Selection completed with \(points.count) points")
            self.currentPoints = points
            self.updateVertexBuffer()
        }
    }

    //NOTE: Ray casting algorithm to check if point is inside selection polygon
    public func isPointInSelection(_ point: vec2f) -> Bool {
        guard currentPoints.count >= 3 else { return false }

        // Convert point to same coordinate space as polygon vertices
        let pointNDC = [point].toNDC()[0]
        let ndcPoints = currentPoints.toNDC()
        let n = currentPoints.count

        var inside = false

        // Ray casting algorithm
        for i in 0..<n {
            let j = (i + 1) % n
            let vi = ndcPoints[i]
            let vj = ndcPoints[j]

            // Check if ray from point to right crosses this edge
            if ((vi.y > pointNDC.y) != (vj.y > pointNDC.y))
                && (pointNDC.x < (vj.x - vi.x) * (pointNDC.y - vi.y) / (vj.y - vi.y) + vi.x)
            {
                inside = !inside
            }
        }

        return inside
    }

    //NOTE: Return current selection points
    public func getSelectionPolygon() -> [vec2f] {
        return currentPoints
    }
}
