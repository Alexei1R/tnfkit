// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Combine
import Core
import CoreGraphics
import Foundation

#if os(iOS)
    import UIKit
#endif

// NOTE: - Event Types

/// Represents the state of a gesture event
public enum GestureState: Sendable {
    case began
    case changed
    case ended
    case cancelled

    #if os(iOS)
        /// Convert from UIGestureRecognizer.State
        public init(from uiState: UIGestureRecognizer.State) {
            switch uiState {
            case .began: self = .began
            case .changed: self = .changed
            case .ended: self = .ended
            case .cancelled, .failed: self = .cancelled
            default: self = .cancelled
            }
        }
    #endif
}

/// Direction for swipe gestures
public enum SwipeDirection: Sendable {
    case left
    case right
    case up
    case down

    #if os(iOS)
        /// Convert from UISwipeGestureRecognizer.Direction
        public init(from uiDirection: UISwipeGestureRecognizer.Direction) {
            switch uiDirection {
            case .left: self = .left
            case .right: self = .right
            case .up: self = .up
            case .down: self = .down
            default: self = .right  // Default
            }
        }
    #endif
}

/// Represents types of touch input
public enum TouchType: Sendable {
    case direct
    case indirect
    case pencil
    case unknown

    #if os(iOS)
        /// Convert from UITouch.TouchType
        public init(from uiTouchType: UITouch.TouchType) {
            switch uiTouchType {
            case .direct: self = .direct
            case .indirect: self = .indirect
            case .pencil: self = .pencil
            default: self = .unknown
            }
        }
    #endif
}

/// Information about a single touch point
public struct TouchPoint: Sendable {
    public let position: vec2f
    public let pressure: Float
    public let majorRadius: Float
    public let type: TouchType
    public let timestamp: TimeInterval

    #if os(iOS)
        /// Create a TouchPoint from UITouch
        @MainActor
        public init(from touch: UITouch, in view: UIView) {
            let cgPosition = touch.location(in: view)
            self.position = vec2f(Float(cgPosition.x), Float(cgPosition.y))
            self.pressure = Float(touch.force / max(touch.maximumPossibleForce, 0.0001))
            self.majorRadius = Float(touch.majorRadius)
            self.type = TouchType(from: touch.type)
            self.timestamp = touch.timestamp
        }
    #endif

    public init(
        position: vec2f, pressure: Float = 1.0, majorRadius: Float = 1.0,
        type: TouchType = .direct, timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.position = position
        self.pressure = pressure
        self.majorRadius = majorRadius
        self.type = type
        self.timestamp = timestamp
    }
}

/// Basic touch events
public enum TouchEvent: Sendable {
    case began(touches: [TouchPoint])
    case moved(touches: [TouchPoint])
    case ended(touches: [TouchPoint])
    case cancelled(touches: [TouchPoint])

    /// Get the primary touch position (first touch point)
    public var primaryPosition: vec2f? {
        switch self {
        case .began(let touches),
            .moved(let touches),
            .ended(let touches),
            .cancelled(let touches):
            return touches.first?.position
        }
    }

    /// Get all touch positions
    public var positions: [vec2f] {
        switch self {
        case .began(let touches),
            .moved(let touches),
            .ended(let touches),
            .cancelled(let touches):
            return touches.map { $0.position }
        }
    }

    /// Get all pressure values
    public var pressures: [Float] {
        switch self {
        case .began(let touches),
            .moved(let touches),
            .ended(let touches),
            .cancelled(let touches):
            return touches.map { $0.pressure }
        }
    }
}

/// Complex gesture events
public enum GestureEvent: Sendable {
    case tap(position: vec2f, tapCount: Int)
    case drag(translation: vec2f, velocity: vec2f, state: GestureState, position: vec2f)
    case pinch(scale: Float, velocity: Float, center: vec2f, state: GestureState)
    case rotate(angle: Float, velocity: Float, center: vec2f, state: GestureState)
    case pan(
        translation: vec2f, velocity: vec2f, touchCount: Int, state: GestureState, position: vec2f)
    case longPress(duration: TimeInterval, position: vec2f, state: GestureState)
    case swipe(direction: SwipeDirection, position: vec2f, velocity: vec2f)

    /// Get the position of the gesture
    public var position: vec2f {
        switch self {
        case .tap(let position, _):
            return position
        case .drag(_, _, _, let position):
            return position
        case .pinch(_, _, let center, _):
            return center
        case .rotate(_, _, let center, _):
            return center
        case .pan(_, _, _, _, let position):
            return position
        case .longPress(_, let position, _):
            return position
        case .swipe(_, let position, _):
            return position
        }
    }

    /// Get the state of stateful gestures
    public var state: GestureState? {
        switch self {
        case .drag(_, _, let state, _):
            return state
        case .pinch(_, _, _, let state):
            return state
        case .rotate(_, _, _, let state):
            return state
        case .pan(_, _, _, let state, _):
            return state
        case .longPress(_, _, let state):
            return state
        default:
            return nil
        }
    }
}

// NOTE: - Central Event Publisher
@MainActor
public final class EventPublisher: Sendable {
    public static let shared = EventPublisher()

    private init() {}

    // NOTE: Event Publishers

    public let touchEvents = PassthroughSubject<TouchEvent, Never>()
    public let gestureEvents = PassthroughSubject<GestureEvent, Never>()

    // NOTE: Convenience Publishers
    /// Convenience publisher for tap events
    public var tapEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case .tap = event { return true }
                return false
            }
            .eraseToAnyPublisher()
    }

    /// Convenience publisher for drag events
    public var dragEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case .drag = event { return true }
                return false
            }
            .eraseToAnyPublisher()
    }
    /// Convenience publisher for pinch events
    public var pinchEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case .pinch = event { return true }
                return false
            }
            .eraseToAnyPublisher()
    }
    /// Convenience publisher for rotation events
    public var rotateEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case .rotate = event { return true }
                return false
            }
            .eraseToAnyPublisher()
    }
    /// Convenience publisher for pan events
    public var panEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case .pan = event { return true }
                return false
            }
            .eraseToAnyPublisher()
    }
    /// Convenience publisher for long press events
    public var longPressEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case .longPress = event { return true }
                return false
            }
            .eraseToAnyPublisher()
    }
    /// Convenience publisher for swipe events
    public var swipeEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case .swipe = event { return true }
                return false
            }
            .eraseToAnyPublisher()
    }
    /// Convenience publisher for multi-touch (2 finger) pan events
    public var twoFingerPanEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if case let .pan(_, _, touchCount, _, _) = event, touchCount == 2 {
                    return true
                }
                return false
            }
            .eraseToAnyPublisher()
    }
    /// Convenience publisher for stateful gesture began events
    public var gestureBeganEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if let state = event.state, state == .began {
                    return true
                }
                return false
            }
            .eraseToAnyPublisher()
    }

    /// Convenience publisher for stateful gesture ended events
    public var gestureEndedEvents: AnyPublisher<GestureEvent, Never> {
        return
            gestureEvents
            .filter { event in
                if let state = event.state, state == .ended || state == .cancelled {
                    return true
                }
                return false
            }
            .eraseToAnyPublisher()
    }

    // NOTE: - Event Emission Methods

    public func emitTouchEvent(_ event: TouchEvent) {
        touchEvents.send(event)
    }
    public func emitGestureEvent(_ event: GestureEvent) {
        gestureEvents.send(event)
    }
    public func emitTap(at position: vec2f, tapCount: Int = 1) {
        gestureEvents.send(.tap(position: position, tapCount: tapCount))
    }
    public func emitDrag(translation: vec2f, velocity: vec2f, state: GestureState, position: vec2f)
    {
        gestureEvents.send(
            .drag(
                translation: translation, velocity: velocity,
                state: state, position: position))
    }
    public func emitPinch(scale: Float, velocity: Float, center: vec2f, state: GestureState) {
        gestureEvents.send(
            .pinch(
                scale: scale, velocity: velocity,
                center: center, state: state))
    }
    public func emitRotation(angle: Float, velocity: Float, center: vec2f, state: GestureState) {
        gestureEvents.send(
            .rotate(
                angle: angle, velocity: velocity,
                center: center, state: state))
    }
    public func emitPan(
        translation: vec2f, velocity: vec2f, touchCount: Int, state: GestureState,
        position: vec2f
    ) {
        gestureEvents.send(
            .pan(
                translation: translation, velocity: velocity,
                touchCount: touchCount, state: state, position: position))
    }
    public func emitLongPress(duration: TimeInterval, position: vec2f, state: GestureState) {
        gestureEvents.send(.longPress(duration: duration, position: position, state: state))
    }
    public func emitSwipe(direction: SwipeDirection, position: vec2f, velocity: vec2f) {
        gestureEvents.send(.swipe(direction: direction, position: position, velocity: velocity))
    }
}
