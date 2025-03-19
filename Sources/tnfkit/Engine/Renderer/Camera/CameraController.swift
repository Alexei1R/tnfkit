// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Combine
import Foundation

@MainActor
public class CameraController {
    // Camera reference
    private let camera: Camera

    // Event handling
    private let eventPublisher: EventPublisher
    private var cancellables = Set<AnyCancellable>()

    // Camera control parameters
    private var rotationSensitivity: Float = 5.0
    private var zoomSensitivity: Float = 5.0
    private var panSensitivity: Float = 10.0

    // Tracking for gesture states
    private var lastDragPosition: vec2f? = nil

    // State flags
    // Set to false in production to reduce logging
    private var debugMode: Bool = false
    private var isEnabled: Bool = true

    // View dimensions for denormalizing if needed
    private var viewWidth: Float = 1.0
    private var viewHeight: Float = 1.0

    // Constructor
    public init(camera: Camera, eventPublisher: EventPublisher = EventPublisher.shared) {
        self.camera = camera
        self.eventPublisher = eventPublisher
        Log.info("CameraController initializing...")
        setupEventHandlers()
    }

    public func setViewDimensions(width: Float, height: Float) {
        viewWidth = width
        viewHeight = height
    }

    private func setupEventHandlers() {
        // CRITICAL: Subscribe to raw touch events for direct manipulation
        eventPublisher.touchEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self, self.isEnabled else { return }

                switch event {
                case .began(let touches):
                    if touches.count == 1 {
                        self.lastDragPosition = touches[0].position
                    } else {
                        self.lastDragPosition = nil
                    }

                case .moved(let touches):
                    if touches.count == 1, let lastPos = self.lastDragPosition {
                        // Single touch move - handle rotation
                        let currentPos = touches[0].position
                        let deltaX = currentPos.x - lastPos.x
                        let deltaY = currentPos.y - lastPos.y
                        
                        // Only apply rotation if there's meaningful movement
                        // This prevents tiny jitters from getting logged
                        if abs(deltaX) > 0.001 || abs(deltaY) > 0.001 {
                            // Apply rotation with higher sensitivity
                            let deltaTheta = -deltaX * self.rotationSensitivity
                            let deltaPhi = -deltaY * self.rotationSensitivity

                            self.camera.orbit(deltaTheta: deltaTheta, deltaPhi: deltaPhi)
                            if self.debugMode {
                                Log.info("Camera rotated: θ=\(deltaTheta), φ=\(deltaPhi)")
                            }
                            
                            // Update last position
                            self.lastDragPosition = currentPos
                        }
                    }

                case .ended, .cancelled:
                    self.lastDragPosition = nil
                }
            }
            .store(in: &cancellables)

        // Keep pinch handler for zooming since it's working well
        eventPublisher.pinchEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self, self.isEnabled else { return }

                if case let .pinch(scale, velocity, center, state) = event {
                    if self.debugMode {
                        Log.info(
                            "Pinch event: scale=\(scale), velocity=\(velocity), center=\(center)")
                    }
                    switch state {
                    case .began:
                        if self.debugMode { Log.info("Zoom began with scale \(scale)") }
                    case .changed:
                        // Calculate zoom delta based on pinch scale
                        // Use a more consistent formula with better normalization
                        let zoomFactor = scale - 1.0
                        let scaledSensitivity =
                            self.zoomSensitivity * min(self.camera.radius / 5.0, 10.0)
                        let zoomDelta = -zoomFactor * scaledSensitivity

                        self.camera.zoom(delta: zoomDelta)
                        if self.debugMode { Log.info("Camera zoomed: delta=\(zoomDelta)") }
                    case .ended, .cancelled:
                        if self.debugMode { Log.info("Zoom ended") }
                    }
                }
            }
            .store(in: &cancellables)

        // Two-finger pan events for camera panning
        eventPublisher.panEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self, self.isEnabled else { return }

                if case let .pan(translation, velocity, touchCount, state, position) = event {
                    if touchCount == 2 {  // Ensure we only handle two-finger pans
                        switch state {
                        case .began:
                            if self.debugMode { Log.info("Pan began with \(touchCount) fingers") }
                        case .changed:
                            // For normalized coords, scale by sensitivity
                            let deltaX = Float(translation.x) * self.panSensitivity
                            let deltaY = Float(translation.y) * self.panSensitivity

                            self.camera.pan(deltaX: -deltaX, deltaY: deltaY)
                            if self.debugMode {
                                Log.info("Camera panned: x=\(deltaX), y=\(deltaY)")
                            }
                        case .ended, .cancelled:
                            if self.debugMode { Log.info("Pan ended") }
                        }
                    }
                }
            }
            .store(in: &cancellables)

        Log.info("Camera event handlers set up")
    }

    // Enable or disable camera control
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    // Public methods to adjust sensitivities
    public func setRotationSensitivity(_ value: Float) {
        rotationSensitivity = value
    }

    public func setZoomSensitivity(_ value: Float) {
        zoomSensitivity = value
    }

    public func setPanSensitivity(_ value: Float) {
        panSensitivity = value
    }

    public func setDebugMode(_ enabled: Bool) {
        debugMode = enabled
    }
}
