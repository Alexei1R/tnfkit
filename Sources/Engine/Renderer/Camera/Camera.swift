// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Foundation
import simd

public enum CameraProjection {
    case perspective
    case orthographic
}

public enum CameraMovementMode {
    case orbit
    case flight
}

public class Camera {
    // Core properties
    private(set) public var position: vec3f
    private(set) public var target: vec3f
    private(set) public var up: vec3f
    public let projectionType: CameraProjection
    public let movementMode: CameraMovementMode

    // Orbital parameters
    private(set) public var radius: Float
    private(set) public var phi: Float
    private(set) public var theta: Float

    // Projection parameters
    private(set) public var fieldOfView: Float
    private(set) public var aspectRatio: Float
    private(set) public var nearPlane: Float
    private(set) public var farPlane: Float
    private var orthoWidth: Float = 10.0
    private var orthoHeight: Float = 10.0

    // Matrices
    private(set) public var viewMatrix: mat4f = .identity
    private(set) public var projectionMatrix: mat4f = .identity

    // Constraints
    private let minPhi: Float = -Float.pi / 2 + 0.01
    private let maxPhi: Float = Float.pi / 2 - 0.01
    private let minRadius: Float = 0.1

    public init(
        position: vec3f = vec3f(0, 0, -5),
        target: vec3f = vec3f(0, 0, 0),
        up: vec3f = vec3f(0, 1, 0),
        projectionType: CameraProjection = .perspective,
        movementMode: CameraMovementMode = .orbit,
        fieldOfView: Float = Float.pi / 3,
        aspectRatio: Float = 1.0,
        nearPlane: Float = 0.1,
        farPlane: Float = 100.0
    ) {
        self.position = position
        self.target = target
        self.up = normalize(up)
        self.projectionType = projectionType
        self.movementMode = movementMode
        self.fieldOfView = fieldOfView
        self.aspectRatio = aspectRatio
        self.nearPlane = nearPlane
        self.farPlane = farPlane

        let offset = position - target
        self.radius = length(offset)
        self.phi = asin(offset.y / max(self.radius, 0.001))
        self.theta = atan2(offset.x, offset.z)

        self.orthoWidth = self.radius * 2.0
        self.orthoHeight = self.orthoWidth / aspectRatio

        updateViewMatrix()
        updateProjectionMatrix()
    }

    private func updateViewMatrix() {
        if movementMode == .orbit {
            position =
                target
                + vec3f(
                    radius * cos(phi) * sin(theta),
                    radius * sin(phi),
                    radius * cos(phi) * cos(theta)
                )
        }

        viewMatrix = .lookAt(eye: position, target: target, up: up)
    }

    private func updateProjectionMatrix() {
        switch projectionType {
        case .perspective:
            projectionMatrix = .perspective(
                fovYRadians: fieldOfView,
                aspect: aspectRatio,
                nearZ: nearPlane,
                farZ: farPlane
            )
        case .orthographic:
            let halfWidth = orthoWidth * 0.5
            let halfHeight = orthoHeight * 0.5
            projectionMatrix = .orthographic(
                left: -halfWidth, right: halfWidth,
                bottom: -halfHeight, top: halfHeight,
                nearZ: nearPlane, farZ: farPlane
            )
        }
    }

    public func getViewMatrix() -> mat4f {
        return viewMatrix
    }

    public func getProjectionMatrix() -> mat4f {
        return projectionMatrix
    }

    public func getViewProjectionMatrix() -> mat4f {
        return projectionMatrix * viewMatrix
    }

    public func orbit(deltaTheta: Float, deltaPhi: Float) {
        theta += deltaTheta
        phi = clamp(phi + deltaPhi, minPhi, maxPhi)

        updateViewMatrix()
    }

    public func zoom(delta: Float) {
        radius = max(minRadius, radius + delta)

        if projectionType == .orthographic {
            orthoWidth = radius * 2.0
            orthoHeight = orthoWidth / aspectRatio
            updateProjectionMatrix()
        }

        updateViewMatrix()
    }

    public func pan(deltaX: Float, deltaY: Float) {
        let forward = normalize(target - position)
        let right = normalize(cross(forward, up))
        let trueUp = normalize(cross(right, forward))

        let movement = right * deltaX + trueUp * deltaY

        position += movement
        target += movement

        updateViewMatrix()
    }

    // Update camera configuration

    public func setPosition(_ newPosition: vec3f) {
        position = newPosition

        if movementMode == .orbit {
            let offset = position - target
            radius = length(offset)
            phi = asin(offset.y / max(radius, 0.001))
            theta = atan2(offset.x, offset.z)
        }

        updateViewMatrix()
    }

    public func setTarget(_ newTarget: vec3f) {
        target = newTarget
        updateViewMatrix()
    }

    public func setUp(_ newUp: vec3f) {
        up = normalize(newUp)
        updateViewMatrix()
    }

    public func setAspectRatio(_ ratio: Float) {
        aspectRatio = ratio

        if projectionType == .orthographic {
            orthoHeight = orthoWidth / aspectRatio
        }

        updateProjectionMatrix()
    }

    public func setFieldOfView(_ fov: Float) {
        fieldOfView = clamp(fov, 0.1, Float.pi - 0.1)
        if projectionType == .perspective {
            updateProjectionMatrix()
        }
    }

    public func setNearPlane(_ near: Float) {
        nearPlane = max(0.001, near)
        updateProjectionMatrix()
    }

    public func setFarPlane(_ far: Float) {
        farPlane = max(nearPlane + 0.1, far)
        updateProjectionMatrix()
    }

    public func setOrthographicSize(width: Float) {
        orthoWidth = max(0.1, width)
        orthoHeight = orthoWidth / aspectRatio

        if projectionType == .orthographic {
            updateProjectionMatrix()
        }
    }

    // Extension points for future camera capabilities

    public func lookAt(target newTarget: vec3f, up newUp: vec3f? = nil) {
        target = newTarget
        if let newUp = newUp {
            up = normalize(newUp)
        }
        updateViewMatrix()
    }

    public func move(direction: vec3f, distance: Float) {
        position += direction * distance

        if movementMode == .orbit {
            let offset = position - target
            radius = length(offset)
            phi = asin(offset.y / max(radius, 0.001))
            theta = atan2(offset.x, offset.z)
        }

        updateViewMatrix()
    }

    public func getForwardVector() -> vec3f {
        return normalize(target - position)
    }

    public func getRightVector() -> vec3f {
        let forward = getForwardVector()
        return normalize(cross(forward, up))
    }

    public func getUpVector() -> vec3f {
        let forward = getForwardVector()
        let right = getRightVector()
        return normalize(cross(right, forward))
    }

    private func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
        Swift.min(Swift.max(value, min), max)
    }
}

extension Camera {
    public static func createDefaultCamera() -> Camera {
        return Camera(
            position: vec3f(0, 2, -5),
            target: vec3f(0, 0, 0),
            up: vec3f(0, 1, 0),
            projectionType: .perspective,
            movementMode: .orbit,
            fieldOfView: Float.pi / 3,
            aspectRatio: 1.0,
            nearPlane: 0.1,
            farPlane: 1000.0
        )
    }

    public static func createOrthographicCamera() -> Camera {
        return Camera(
            position: vec3f(0, 0, -3),
            target: vec3f(0, 0, 0),
            up: vec3f(0, 1, 0),
            projectionType: .orthographic,
            movementMode: .orbit,
            aspectRatio: 1.0,
            nearPlane: 0.1,
            farPlane: 1000.0
        )
    }
}

