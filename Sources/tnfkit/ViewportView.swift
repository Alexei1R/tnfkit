// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Combine
import Core
import Engine
import MetalKit
import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@MainActor
public struct PositionNormalizer {
    #if os(iOS)
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
    #elseif os(macOS)
        static func normalizePosition(_ point: CGPoint, in view: NSView) -> vec2f {
            return vec2f(
                Float(point.x / view.bounds.width),
                Float(point.y / view.bounds.height)
            )
        }

        static func normalizeVector(_ vector: vec2f, in view: NSView) -> vec2f {
            return vec2f(
                vector.x / Float(view.bounds.width),
                vector.y / Float(view.bounds.height)
            )
        }
    #endif
}

#if os(iOS)
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
        private var initialScale: CGFloat = 1.0
        private var isHandlingDirectTouch: Bool = false

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

#elseif os(macOS)
    @MainActor
    public struct ViewportView: NSViewRepresentable {
        private let engine: TNFEngine
        private let eventPublisher: EventPublisher

        public init(engine: TNFEngine, eventPublisher: EventPublisher = EventPublisher.shared) {
            self.engine = engine
            self.eventPublisher = eventPublisher
        }

        public func makeNSView(context: Context) -> MTKView {
            let view = MTKView()
            view.device = engine.getMetalDevice()
            view.delegate = context.coordinator
            view.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)
            view.enableSetNeedsDisplay = true
            view.preferredFramesPerSecond = 60

            engine.start(with: view)

            return view
        }

        public func updateNSView(_ nsView: MTKView, context: Context) {}

        public func makeCoordinator() -> ViewportCoordinator {
            return ViewportCoordinator(engine: engine, eventPublisher: eventPublisher)
        }
    }

    @MainActor
    public class ViewportCoordinator: NSObject, MTKViewDelegate {
        private let engine: TNFEngine
        private let eventPublisher: EventPublisher

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
#endif

#if os(iOS)
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
            if (gestureRecognizer is UIPinchGestureRecognizer
                && otherGestureRecognizer is UIRotationGestureRecognizer)
                || (gestureRecognizer is UIRotationGestureRecognizer
                    && otherGestureRecognizer is UIPinchGestureRecognizer)
            {
                return true
            }

            if gestureRecognizer is UITapGestureRecognizer
                || otherGestureRecognizer is UITapGestureRecognizer
            {
                return false
            }

            return false
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            if isHandlingDirectTouch {
                return false
            }

            if let tapGesture = gestureRecognizer as? UITapGestureRecognizer,
                tapGesture.state != .possible && tapGesture.state != .ended
                    && tapGesture.state != .cancelled
            {
                tapGesture.state = .cancelled
            }

            return true
        }
    }

    @MainActor
    extension ViewportCoordinator: TouchEventDelegate {
        public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
            isHandlingDirectTouch = true
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
            eventPublisher.emitTouchEvent(.began(touches: touchPoints))
        }

        public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
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

        public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
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
            isHandlingDirectTouch = false
        }

        public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView)
        {
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
            isHandlingDirectTouch = false
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

            let location = sender.location(in: view)
            let velocity = sender.velocity(in: view)
            let translation = sender.translation(in: view)

            let normalizedPosition = PositionNormalizer.normalizePosition(location, in: view)
            let normalizedVelocity = PositionNormalizer.normalizeVector(
                vec2f(Float(velocity.x), Float(velocity.y)),
                in: view
            )
            let normalizedTranslation = PositionNormalizer.normalizeVector(
                vec2f(Float(translation.x), Float(translation.y)),
                in: view
            )
            let state = GestureState(from: sender.state)

            eventPublisher.emitDrag(
                translation: normalizedTranslation,
                velocity: normalizedVelocity,
                state: state,
                position: normalizedPosition
            )

            eventPublisher.emitPan(
                translation: normalizedTranslation,
                velocity: normalizedVelocity,
                touchCount: sender.numberOfTouches,
                state: state,
                position: normalizedPosition
            )

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

            let location = sender.location(in: view)
            let normalizedCenter = PositionNormalizer.normalizePosition(location, in: view)
            let state = GestureState(from: sender.state)

            eventPublisher.emitPinch(
                scale: Float(sender.scale),
                velocity: Float(sender.velocity),
                center: normalizedCenter,
                state: state
            )

            if sender.state == .began {
                initialScale = sender.scale
            }
        }

        @objc public func handleRotationGesture(_ sender: UIRotationGestureRecognizer) {
            guard let view = sender.view else { return }

            if sender.state != .began && sender.state != .changed && sender.state != .ended
                && sender.state != .cancelled
            {
                return
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
        }
    }
#endif
