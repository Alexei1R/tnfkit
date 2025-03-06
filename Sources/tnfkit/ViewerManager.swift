// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Combine
import Core
import Engine
import Foundation
import MetalKit
import SwiftUI

@MainActor
class ViewerManager {
    private let toolManager: ToolManager
    private var renderer: Renderer?
    private var currentCamera: Camera
    private var cameraController: CameraController
    private var models: [StaticModel] = []
    private var selectionArea: SelectionArea?
    private var grid: GridRenderer?
    private var rotationAngle: Float = 0.0
    private var lastUpdateTime = CACurrentMediaTime()
    private var cancellables = Set<AnyCancellable>()  // Keep reference to cancellables

    public init(toolManager: ToolManager) {
        self.toolManager = toolManager
        self.currentCamera = Camera.createDefaultCamera()

        // Initialize camera controller
        self.cameraController = CameraController(camera: currentCamera)
        self.cameraController.setRotationSensitivity(5.0)
        self.cameraController.setZoomSensitivity(5.0)
        self.cameraController.setPanSensitivity(10.0)

        // Configure tool-specific behaviors
        configureToolManager()

        Log.info("ViewerManager initialized")
    }

    private func configureToolManager() {
        Task { @MainActor @Sendable in
            // Configure selection tool if available
            if let selectionTool = toolManager.getTool(.select) as? SelectionTool {
                // Handler for selection changes (during dragging)
                selectionTool.setSelectionChangeHandler { [weak self] points in
                    guard let self = self, self.toolManager.isToolActive(.select) else { return }

                    // Only update selection area when select tool is active
                    self.selectionArea?.updateSelectionPoints(points.toNDC())
                }

                // Handler for selection completion (when drag ends)
                selectionTool.setSelectionCompletionHandler { [weak self] points in
                    guard let self = self, self.toolManager.isToolActive(.select) else { return }

                    if points.isEmpty {
                        // Clear selection if empty
                        self.selectionArea?.clearSelection()
                    } else {
                        // Process the selection then clear it
                        let ndcPoints = points.toNDC()
                        self.processCompletedSelection(ndcPoints)
                    }
                }
            }

            // Monitor for tool changes
            Timer.publish(every: 0.5, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.updateToolState()
                }
                .store(in: &cancellables)
        }
    }

    private func updateToolState() {
        let isControlActive = toolManager.isToolActive(.control)
        cameraController.setEnabled(isControlActive)

        let isSelectionActive = toolManager.isToolActive(.select)

        // Update selection visibility based on active tool
        selectionArea?.setVisible(isSelectionActive)

        // If not using selection tool, clear any existing selection
        if !isSelectionActive {
            selectionArea?.clearSelection()
        }
    }

    private func processCompletedSelection(_ points: [vec2f]) {
        // Only process selection if selection tool is active
        guard toolManager.isToolActive(.select) else { return }

        // Do any processing needed with the selection points
        Log.info("Processing selection with \(points.count) points")

        // Clear the selection
        selectionArea?.completeSelection(points)
    }

    func start(view: MTKView) {
        guard let renderer = Renderer(view: view) else {
            Log.error("Failed to create renderer")
            return
        }
        self.renderer = renderer

        // Set view dimensions for the camera controller
        cameraController.setViewDimensions(
            width: Float(view.bounds.width), height: Float(view.bounds.height))

        // Set up the 3D model
        let model = StaticModel(modelPath: "model")
        model.transform = mat4f.identity
            .translate(vec3f(-2, 0, 0))
            .rotateDegrees(-90.0, axis: .x)
        models.append(model)
        renderer.addRenderable(model)

        // Set up the 3D model
        let girl = StaticModel(modelPath: "girl")
        girl.transform = mat4f.identity
            .scale(vec3f.one * 0.03)
            .translate(vec3f(0, -2, 0))
        models.append(girl)
        renderer.addRenderable(girl)

        // Set up the selection area
        let selection = SelectionArea()
        selectionArea = selection
        renderer.addRenderable(selection)

        // Set up the grid - only showing XZ plane with all axes
        let grid = GridRenderer(gridSize: 20.0, cellSize: 1.0, minorCellCount: 5)
        self.grid = grid
        renderer.addRenderable(grid)

        // Update tool state based on active tool
        updateToolState()

        Log.info(
            "ViewerManager started with view size: \(view.bounds.width) x \(view.bounds.height)")
    }

    func resize(size: vec2i) {
        currentCamera.setAspectRatio(Float(size.x) / Float(size.y))
        renderer?.resize(size: size)

        // Update view dimensions in camera controller
        cameraController.setViewDimensions(width: Float(size.x), height: Float(size.y))
    }

    func update(dt: Float, view: MTKView) {
        guard let renderer = renderer else { return }

        renderer.beginFrame(camera: currentCamera, view: view)
        renderer.endFrame()
    }

    // Helper methods for camera control
    func setCameraRotationSensitivity(_ value: Float) {
        cameraController.setRotationSensitivity(value)
    }

    func setCameraZoomSensitivity(_ value: Float) {
        cameraController.setZoomSensitivity(value)
    }

    func setCameraPanSensitivity(_ value: Float) {
        cameraController.setPanSensitivity(value)
    }

    // Reset camera to default view
    func resetCamera() {
        currentCamera = Camera.createDefaultCamera()
        cameraController = CameraController(camera: currentCamera)

        // Set sensitivity settings
        cameraController.setRotationSensitivity(5.0)
        cameraController.setZoomSensitivity(5.0)
        cameraController.setPanSensitivity(10.0)

        // Update control state based on active tool
        let isControlActive = toolManager.isToolActive(.control)
        cameraController.setEnabled(isControlActive)
    }
}

// Extension to add visibility control to SelectionArea if needed
extension SelectionArea {
    func setVisible(_ visible: Bool) {
        // Implement this method based on your SelectionArea class
        // This might set a visibility flag that controls rendering
    }
}

