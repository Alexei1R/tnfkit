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
    private var selectableModels: [SelectableModel] = []
    private var selectionArea: SelectionArea?
    private var grid: GridRenderer?
    private var modelSelectionProcessor: ModelSelectionProcessor?

    private var rotationAngle: Float = 0.0
    private var lastUpdateTime = CACurrentMediaTime()
    private var cancellables = Set<AnyCancellable>()

    public init(toolManager: ToolManager) {
        self.toolManager = toolManager
        self.currentCamera = Camera.createDefaultCamera()
        self.cameraController = CameraController(camera: currentCamera)
        self.cameraController.setRotationSensitivity(5.0)
        self.cameraController.setZoomSensitivity(5.0)
        self.cameraController.setPanSensitivity(10.0)

        configureToolManager()
    }

    private func configureToolManager() {
        Task { @MainActor @Sendable in
            if let selectionTool = toolManager.getTool(.select) as? SelectionTool {
                selectionTool.setSelectionChangeHandler { [weak self] points in
                    guard let self = self, self.toolManager.isToolActive(.select) else { return }
                    self.selectionArea?.updateSelectionPoints(points.toNDC())
                }

                selectionTool.setSelectionCompletionHandler { [weak self] points in
                    guard let self = self, self.toolManager.isToolActive(.select) else { return }

                    if points.isEmpty {
                        self.selectionArea?.clearSelection()
                    } else {
                        let ndcPoints = points.toNDC()
                        self.processCompletedSelection(ndcPoints)
                    }
                }
            }

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
        selectionArea?.setVisible(isSelectionActive)

        if !isSelectionActive {
            selectionArea?.clearSelection()
        }
    }

    private func processCompletedSelection(_ points: [vec2f]) {
        guard toolManager.isToolActive(.select) else { return }

        processVertexSelection()
        selectionArea?.completeSelection(points)
    }

    private func processVertexSelection() {
        guard let modelSelectionProcessor = modelSelectionProcessor,
            !selectableModels.isEmpty
        else {
            return
        }

        modelSelectionProcessor.processSelectionForModels(
            models: selectableModels,
            camera: currentCamera
        )
    }

    func start(view: MTKView) {
        guard let renderer = Renderer(view: view) else {
            return
        }
        self.renderer = renderer

        cameraController.setViewDimensions(
            width: Float(view.bounds.width), height: Float(view.bounds.height))

        self.modelSelectionProcessor = ModelSelectionProcessor(renderer: renderer)

        // Set up selection area
        let selection = SelectionArea()
        selectionArea = selection
        renderer.addRenderable(selection)

        // Set up grid
        let grid = GridRenderer(gridSize: 20.0, cellSize: 1.0, minorCellCount: 5)
        self.grid = grid
        renderer.addRenderable(grid)

        updateToolState()
    }

    func resize(size: vec2i) {
        currentCamera.setAspectRatio(Float(size.x) / Float(size.y))
        renderer?.resize(size: size)
        cameraController.setViewDimensions(width: Float(size.x), height: Float(size.y))
    }

    func update(dt: Float, view: MTKView) {
        guard let renderer = renderer else { return }

        //FIXME: Load Scenes
        let scene = SceneManager.shared.scene
        //FIXME: update the scene
        var selection = scene.selection(of: MeshComponent.self)
        selection.forEach { entity in
            if let mesh: MeshComponent = scene.get(for: entity) {
                if mesh.isInitialized == false {
                    Log.info(
                        "Model ==================================================: \(mesh.name)")
                    //NOTE: Initialize the mesh
                    let selectableModel = SelectableModel(modelPath: mesh.name)
                    //NOTE: Add meshes to the renderer
                    selectableModels.append(selectableModel)
                    renderer.addRenderable(selectableModel)
                    mesh.isInitialized = true
                    return
                } else {

                }
            }

        }

        renderer.beginFrame(camera: currentCamera, view: view)
        renderer.endFrame()
    }

    func setCameraRotationSensitivity(_ value: Float) {
        cameraController.setRotationSensitivity(value)
    }

    func setCameraZoomSensitivity(_ value: Float) {
        cameraController.setZoomSensitivity(value)
    }

    func setCameraPanSensitivity(_ value: Float) {
        cameraController.setPanSensitivity(value)
    }

    func resetCamera() {
        currentCamera = Camera.createDefaultCamera()
        cameraController = CameraController(camera: currentCamera)
        cameraController.setRotationSensitivity(5.0)
        cameraController.setZoomSensitivity(5.0)
        cameraController.setPanSensitivity(10.0)
        cameraController.setEnabled(toolManager.isToolActive(.control))
    }

    func clearAllSelections() {
        guard let modelSelectionProcessor = modelSelectionProcessor else { return }

        for model in selectableModels {
            modelSelectionProcessor.clearSelection(model: model)
        }
    }
}
