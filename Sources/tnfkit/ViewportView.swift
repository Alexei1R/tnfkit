// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Combine
import MetalKit
import SwiftUI
import UIKit

@MainActor
public struct PositionNormalizer {
    static func normalizePosition(_ point: CGPoint, in view: UIView) -> vec2f {
        return vec2f(
            Float(point.x / view.bounds.width),
            Float(point.y / view.bounds.height)
        )
    }

    static func normalizeVector(_ vector: vec2f, in view: UIView) -> vec2f {
        return vec2f(
            vector.x / Float(view.bounds.width),
            vector.y / Float(view.bounds.height)
        )
    }
}

public class TouchEnabledMTKView: MTKView {
    weak var touchDelegate: TouchEventDelegate?

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchesBegan(touches, with: event, in: self)
        super.touchesBegan(touches, with: event)
    }
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchesMoved(touches, with: event, in: self)
        super.touchesMoved(touches, with: event)
    }
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchesEnded(touches, with: event, in: self)
        super.touchesEnded(touches, with: event)
    }
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchesCancelled(touches, with: event, in: self)
        super.touchesCancelled(touches, with: event)
    }
}

@MainActor public protocol TouchEventDelegate: AnyObject {
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView)
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView)
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView)
    func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView)
}

@MainActor
public struct ViewportView: UIViewRepresentable {
    private let engine: TNFEngine
    private let eventPublisher: EventPublisher

    public init(engine: TNFEngine, eventPublisher: EventPublisher = EventPublisher.shared) {
        self.engine = engine
        self.eventPublisher = eventPublisher
    }

    public func makeUIView(context: Context) -> TouchEnabledMTKView {
        let view = TouchEnabledMTKView()
        view.device = engine.getMetalDevice()
        view.delegate = context.coordinator
        view.touchDelegate = context.coordinator
        view.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.isMultipleTouchEnabled = true

        view.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float

        engine.start(with: view)
        setupGestureRecognizers(for: view, with: context.coordinator)

        return view
    }

    public func updateUIView(_ uiView: TouchEnabledMTKView, context: Context) {}

    public func makeCoordinator() -> ViewportCoordinator {
        return ViewportCoordinator(engine: engine, eventPublisher: eventPublisher)
    }

    private func setupGestureRecognizers(
        for view: UIView, with coordinator: ViewportCoordinator
    ) {
        let doubleTapGesture = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(ViewportCoordinator.handleDoubleTapGesture(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        doubleTapGesture.delegate = coordinator
        doubleTapGesture.delaysTouchesBegan = false
        doubleTapGesture.delaysTouchesEnded = true
        view.addGestureRecognizer(doubleTapGesture)

        let tapGesture = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(ViewportCoordinator.handleTapGesture(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        tapGesture.delegate = coordinator
        tapGesture.delaysTouchesBegan = false
        tapGesture.delaysTouchesEnded = false
        tapGesture.require(toFail: doubleTapGesture)
        view.addGestureRecognizer(tapGesture)

        let longTapGesture = UILongPressGestureRecognizer(
            target: coordinator,
            action: #selector(ViewportCoordinator.handleLongTapGesture(_:)))
        longTapGesture.minimumPressDuration = 0.5
        longTapGesture.delegate = coordinator
        longTapGesture.delaysTouchesBegan = false
        view.addGestureRecognizer(longTapGesture)

        let directions: [UISwipeGestureRecognizer.Direction] = [.right, .left, .up, .down]
        for direction in directions {
            let swipeGesture = UISwipeGestureRecognizer(
                target: coordinator,
                action: #selector(ViewportCoordinator.handleSwipeGesture(_:)))
            swipeGesture.direction = direction
            swipeGesture.delegate = coordinator
            swipeGesture.delaysTouchesBegan = false
            view.addGestureRecognizer(swipeGesture)
        }

        let panGesture = UIPanGestureRecognizer(
            target: coordinator,
            action: #selector(ViewportCoordinator.handlePanGesture(_:)))
        panGesture.delegate = coordinator
        panGesture.maximumNumberOfTouches = 1
        panGesture.delaysTouchesBegan = false
        view.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(
            target: coordinator,
            action: #selector(ViewportCoordinator.handlePinchGesture(_:)))
        pinchGesture.delegate = coordinator
        pinchGesture.delaysTouchesBegan = false
        view.addGestureRecognizer(pinchGesture)

        let rotationGesture = UIRotationGestureRecognizer(
            target: coordinator,
            action: #selector(ViewportCoordinator.handleRotationGesture(_:)))
        rotationGesture.delegate = coordinator
        rotationGesture.delaysTouchesBegan = false
        view.addGestureRecognizer(rotationGesture)
    }
}

@MainActor
public class ViewportCoordinator: NSObject, MTKViewDelegate {
    private let engine: TNFEngine
    private let eventPublisher: EventPublisher
    private var lastPanLocation: CGPoint = .zero
    private var lastPanTranslation: CGPoint = .zero
    private var initialScale: CGFloat = 1.0
    private var isHandlingDirectTouch: Bool = false
    private var activeTouchCount: Int = 0
    private var twoFingerMode: Bool = false
    private var gestureInProgress: Bool = false

    public init(engine: TNFEngine, eventPublisher: EventPublisher) {
        self.engine = engine
        self.eventPublisher = eventPublisher
        super.init()
    }

    public func draw(in view: MTKView) {
        engine.update(view: view)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        Task { @MainActor in
            engine.resize(to: size)
        }
    }
}

@MainActor
extension ViewportCoordinator: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if isHandlingDirectTouch {
            return false
        }
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Always allow multi-touch gestures to work together
        let multiTouchGestures = [UIPinchGestureRecognizer.self, UIRotationGestureRecognizer.self, UIPanGestureRecognizer.self]
        
        // Check if both are multi-touch gestures
        let isFirstMultiTouch = multiTouchGestures.contains { gestureRecognizer.isKind(of: $0) }
        let isSecondMultiTouch = multiTouchGestures.contains { otherGestureRecognizer.isKind(of: $0) }
        
        // Allow all multi-touch gestures to work together
        if isFirstMultiTouch && isSecondMultiTouch {
            // If pan is involved, make sure it has at least 2 touches
            if gestureRecognizer is UIPanGestureRecognizer {
                let panGR = gestureRecognizer as! UIPanGestureRecognizer
                return panGR.numberOfTouches >= 2
            }
            
            if otherGestureRecognizer is UIPanGestureRecognizer {
                let panGR = otherGestureRecognizer as! UIPanGestureRecognizer
                return panGR.numberOfTouches >= 2
            }
            
            return true
        }
        
        // Always reject tap recognizers working with other gestures
        if gestureRecognizer is UITapGestureRecognizer || otherGestureRecognizer is UITapGestureRecognizer {
            return false
        }
        
        return false
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        // Always prioritize pinch/rotation gestures
        if gestureRecognizer is UIPinchGestureRecognizer || 
           gestureRecognizer is UIRotationGestureRecognizer {
            return true
        }
        
        // If a gesture is already in progress, only allow related gestures
        if gestureInProgress {
            // Only allow pan during gesture in progress if it's a multi-touch pan
            if let panGR = gestureRecognizer as? UIPanGestureRecognizer {
                return activeTouchCount >= 2
            }
            return false
        }
        
        // For pan gestures not during gesture progress
        if let panGR = gestureRecognizer as? UIPanGestureRecognizer {
            if activeTouchCount >= 2 {
                return true
            }
            return !isHandlingDirectTouch
        }
        
        // For single touches during direct touch handling, block other gestures
        if isHandlingDirectTouch && activeTouchCount == 1 {
            return false
        }

        return true
    }
}

@MainActor
extension ViewportCoordinator: TouchEventDelegate {
    public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        if let allTouches = event?.allTouches {
            let oldTouchCount = activeTouchCount
            activeTouchCount = allTouches.count
            
            if activeTouchCount >= 2 {
                twoFingerMode = true
                isHandlingDirectTouch = false
                gestureInProgress = true
            } else if oldTouchCount >= 2 && activeTouchCount == 1 {
                isHandlingDirectTouch = false
                twoFingerMode = true
            } else if !gestureInProgress && activeTouchCount == 1 {
                isHandlingDirectTouch = true
                twoFingerMode = false
            }
        }
        
        let touchPoints = touches.map { touch -> TouchPoint in
            let position = PositionNormalizer.normalizePosition(
                touch.location(in: view), in: view)
            return TouchPoint(
                position: position,
                pressure: Float(touch.force / max(touch.maximumPossibleForce, 0.0001)),
                majorRadius: Float(touch.majorRadius),
                type: TouchType(from: touch.type),
                timestamp: touch.timestamp
            )
        }
        
        if !gestureInProgress || (activeTouchCount == 1 && !twoFingerMode) {
            eventPublisher.emitTouchEvent(.began(touches: touchPoints))
        }
    }

    public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        if let allTouches = event?.allTouches {
            activeTouchCount = allTouches.count
        }
        
        if gestureInProgress && activeTouchCount == 1 {
            return
        }
        
        // Only emit move events for single-finger rotation or explicit two-finger mode
        if (activeTouchCount == 1 && !twoFingerMode) {
            let touchPoints = touches.map { touch -> TouchPoint in
                let position = PositionNormalizer.normalizePosition(
                    touch.location(in: view), in: view)
                return TouchPoint(
                    position: position,
                    pressure: Float(touch.force / max(touch.maximumPossibleForce, 0.0001)),
                    majorRadius: Float(touch.majorRadius),
                    type: TouchType(from: touch.type),
                    timestamp: touch.timestamp
                )
            }
            eventPublisher.emitTouchEvent(.moved(touches: touchPoints))
        }
    }

    public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        if let allTouches = event?.allTouches {
            let oldTouchCount = activeTouchCount
            
            if allTouches.isEmpty || allTouches.count == touches.count {
                activeTouchCount = 0
                isHandlingDirectTouch = false
                twoFingerMode = false
                gestureInProgress = false
                
                let touchPoints = touches.map { touch -> TouchPoint in
                    let position = PositionNormalizer.normalizePosition(
                        touch.location(in: view), in: view)
                    return TouchPoint(
                        position: position,
                        pressure: Float(touch.force / max(touch.maximumPossibleForce, 0.0001)),
                        majorRadius: Float(touch.majorRadius),
                        type: TouchType(from: touch.type),
                        timestamp: touch.timestamp
                    )
                }
                eventPublisher.emitTouchEvent(.ended(touches: touchPoints))
            } else {
                // Just update remaining touch count but don't emit events during gesture transition
                activeTouchCount = allTouches.count
                
                if oldTouchCount >= 2 && activeTouchCount == 1 {
                    // Transitioning from multi-touch to single touch - maintain gesture mode
                    twoFingerMode = true
                    isHandlingDirectTouch = false
                }
            }
        }
    }

    public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        let touchPoints = touches.map { touch -> TouchPoint in
            let position = PositionNormalizer.normalizePosition(
                touch.location(in: view), in: view)
            return TouchPoint(
                position: position,
                pressure: Float(touch.force / max(touch.maximumPossibleForce, 0.0001)),
                majorRadius: Float(touch.majorRadius),
                type: TouchType(from: touch.type),
                timestamp: touch.timestamp
            )
        }
        eventPublisher.emitTouchEvent(.cancelled(touches: touchPoints))
        
        activeTouchCount = 0
        isHandlingDirectTouch = false
        twoFingerMode = false
        gestureInProgress = false
    }
}

@MainActor
extension ViewportCoordinator {
    @objc public func handleTapGesture(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }

        guard sender.state == .ended else { return }

        let location = sender.location(in: view)
        let normalizedPosition = PositionNormalizer.normalizePosition(location, in: view)
        eventPublisher.emitTap(at: normalizedPosition, tapCount: 1)
    }

    @objc public func handleDoubleTapGesture(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }

        guard sender.state == .ended else { return }

        let location = sender.location(in: view)
        let normalizedPosition = PositionNormalizer.normalizePosition(location, in: view)
        eventPublisher.emitTap(at: normalizedPosition, tapCount: 2)
    }

    @objc public func handleLongTapGesture(_ sender: UILongPressGestureRecognizer) {
        guard let view = sender.view else { return }

        if sender.state != .began && sender.state != .changed && sender.state != .ended
            && sender.state != .cancelled
        {
            return
        }

        let location = sender.location(in: view)
        let normalizedPosition = PositionNormalizer.normalizePosition(location, in: view)
        let state = GestureState(from: sender.state)
        eventPublisher.emitLongPress(
            duration: sender.minimumPressDuration,
            position: normalizedPosition,
            state: state
        )
    }

    @objc public func handleSwipeGesture(_ sender: UISwipeGestureRecognizer) {
        guard let view = sender.view else { return }

        guard sender.state == .recognized || sender.state == .ended else { return }

        let location = sender.location(in: view)
        let normalizedPosition = PositionNormalizer.normalizePosition(location, in: view)

        var velocityX: CGFloat = 0
        var velocityY: CGFloat = 0

        switch sender.direction {
        case .right:
            velocityX = 1000
        case .left:
            velocityX = -1000
        case .up:
            velocityY = -1000
        case .down:
            velocityY = 1000
        default:
            break
        }

        let velocity = PositionNormalizer.normalizeVector(
            vec2f(Float(velocityX), Float(velocityY)),
            in: view
        )
        let direction = SwipeDirection(from: sender.direction)
        eventPublisher.emitSwipe(
            direction: direction,
            position: normalizedPosition,
            velocity: velocity
        )
    }

    @objc public func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        guard let view = sender.view else { return }

        if sender.state != .began && sender.state != .changed && sender.state != .ended
            && sender.state != .cancelled
        {
            return
        }
        
        let touchCount = sender.numberOfTouches
        
        if sender.state == .began {
            if touchCount >= 2 {
                gestureInProgress = true
                twoFingerMode = true
                isHandlingDirectTouch = false
                lastPanTranslation = .zero
                sender.setTranslation(.zero, in: view)
            } else if !gestureInProgress && touchCount == 1 {
                isHandlingDirectTouch = true
                twoFingerMode = false
            }
        }

        let location = sender.location(in: view)
        let velocity = sender.velocity(in: view)
        let translation = sender.translation(in: view)
        
        // Get normalized position for reference
        let normalizedPosition = PositionNormalizer.normalizePosition(location, in: view)
        
        // For translations and velocities, use pixel values for more precision
        let rawTranslation = vec2f(Float(translation.x), Float(translation.y))
        let rawVelocity = vec2f(Float(velocity.x), Float(velocity.y))
        
        // Get state from gesture recognizer
        
        let state = GestureState(from: sender.state)

        if touchCount == 1 && !twoFingerMode && !gestureInProgress {
            // Single finger drag = camera rotation
            let normalizedTranslation = PositionNormalizer.normalizeVector(rawTranslation, in: view)
            let normalizedVelocity = PositionNormalizer.normalizeVector(rawVelocity, in: view)
            
            eventPublisher.emitDrag(
                translation: normalizedTranslation,
                velocity: normalizedVelocity,
                state: state,
                position: normalizedPosition
            )
        } else if touchCount >= 2 || (touchCount == 1 && twoFingerMode) {
            // For two-finger pan gestures
            let normalizedTranslation = PositionNormalizer.normalizeVector(rawTranslation, in: view)
            
            eventPublisher.emitPan(
                translation: normalizedTranslation,
                velocity: rawVelocity,
                touchCount: max(2, touchCount),
                state: state,
                position: normalizedPosition
            )
            
            if state == .changed {
                sender.setTranslation(.zero, in: view)
            }
        }

        if sender.state == .ended || sender.state == .cancelled {
            sender.setTranslation(.zero, in: view)
            
            if touchCount <= 1 {
                gestureInProgress = false
            }
        }
        
        if sender.state == .began {
            lastPanLocation = location
        }
    }

    @objc public func handlePinchGesture(_ sender: UIPinchGestureRecognizer) {
        guard let view = sender.view else { return }

        if sender.state != .began && sender.state != .changed && sender.state != .ended
            && sender.state != .cancelled
        {
            return
        }
        
        if sender.state == .began {
            gestureInProgress = true
            twoFingerMode = true
            isHandlingDirectTouch = false
            initialScale = sender.scale
        }

        let location = sender.location(in: view)
        let normalizedCenter = PositionNormalizer.normalizePosition(location, in: view)
        let state = GestureState(from: sender.state)
        
        let adjustedScale: Float
        if sender.state == .began {
            adjustedScale = 1.0
        } else {
            let relativeScale = sender.scale / max(initialScale, 0.001)
            adjustedScale = Float(relativeScale)
        }

        eventPublisher.emitPinch(
            scale: adjustedScale,
            velocity: Float(sender.velocity),
            center: normalizedCenter,
            state: state
        )
        
        if sender.state == .ended || sender.state == .cancelled {
            initialScale = 1.0
            sender.scale = 1.0
            
            if sender.numberOfTouches <= 1 {
                gestureInProgress = false
            }
        }
    }

    @objc public func handleRotationGesture(_ sender: UIRotationGestureRecognizer) {
        guard let view = sender.view else { return }

        if sender.state != .began && sender.state != .changed && sender.state != .ended
            && sender.state != .cancelled
        {
            return
        }
        
        if sender.state == .began {
            gestureInProgress = true
            twoFingerMode = true
            isHandlingDirectTouch = false
        }

        let location = sender.location(in: view)
        let normalizedCenter = PositionNormalizer.normalizePosition(location, in: view)
        let state = GestureState(from: sender.state)

        eventPublisher.emitRotation(
            angle: Float(sender.rotation),
            velocity: Float(sender.velocity),
            center: normalizedCenter,
            state: state
        )
        
        if sender.state == .ended || sender.state == .cancelled {
            sender.rotation = 0
            
            if sender.numberOfTouches <= 1 {
                gestureInProgress = false
            }
        }
    }
}

