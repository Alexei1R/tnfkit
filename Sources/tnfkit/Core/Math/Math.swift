// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import simd

// MARK: - Type Aliases

public typealias vec2u = SIMD2<UInt32>
public typealias vec3u = SIMD3<UInt32>
public typealias vec4u = SIMD4<UInt32>

public typealias vec2i = SIMD2<Int32>
public typealias vec3i = SIMD3<Int32>
public typealias vec4i = SIMD4<Int32>

public typealias vec2f = SIMD2<Float>
public typealias vec3f = SIMD3<Float>
public typealias vec4f = SIMD4<Float>

public typealias mat3f = simd_float3x3
public typealias mat4f = simd_float4x4

public enum Axis {
    case x, y, z
}

// MARK: - Matrix Extensions

extension mat4f {
    // MARK: Basic Properties

    public static var identity: mat4f {
        matrix_identity_float4x4
    }

    // MARK: Component Getters/Setters

    /// Gets or sets the translation component of the matrix
    public var translation: vec3f {
        get {
            vec3f(columns.3.x, columns.3.y, columns.3.z)
        }
        set {
            columns.3.x = newValue.x
            columns.3.y = newValue.y
            columns.3.z = newValue.z
        }
    }

    /// Gets or sets the scale component of the matrix
    public var scale: vec3f {
        get {
            vec3f(
                length(vec3f(columns.0.x, columns.0.y, columns.0.z)),
                length(vec3f(columns.1.x, columns.1.y, columns.1.z)),
                length(vec3f(columns.2.x, columns.2.y, columns.2.z))
            )
        }
        set {
            // Normalize current columns to remove existing scale
            let xAxis = normalize(vec3f(columns.0.x, columns.0.y, columns.0.z))
            let yAxis = normalize(vec3f(columns.1.x, columns.1.y, columns.1.z))
            let zAxis = normalize(vec3f(columns.2.x, columns.2.y, columns.2.z))

            // Apply new scale
            columns.0.x = xAxis.x * newValue.x
            columns.0.y = xAxis.y * newValue.x
            columns.0.z = xAxis.z * newValue.x

            columns.1.x = yAxis.x * newValue.y
            columns.1.y = yAxis.y * newValue.y
            columns.1.z = yAxis.z * newValue.y

            columns.2.x = zAxis.x * newValue.z
            columns.2.y = zAxis.y * newValue.z
            columns.2.z = zAxis.z * newValue.z
        }
    }

    /// Gets or sets the rotation as Euler angles in radians (x: pitch, y: yaw, z: roll)
    public var rotation: vec3f {
        get {
            // Extract the normalized basis vectors
            let scaleVec = self.scale

            let m00 = columns.0.x / scaleVec.x
            let m10 = columns.0.y / scaleVec.x
            let m20 = columns.0.z / scaleVec.x

            let m01 = columns.1.x / scaleVec.y
            let m11 = columns.1.y / scaleVec.y
            let m21 = columns.1.z / scaleVec.y

            let m02 = columns.2.x / scaleVec.z
            let m12 = columns.2.y / scaleVec.z
            let m22 = columns.2.z / scaleVec.z

            var pitch: Float = 0
            var yaw: Float = 0
            var roll: Float = 0

            // Handle gimbal lock cases
            if m20 > 0.99999 {
                pitch = .pi / 2
                yaw = atan2(m01, m11)
                roll = 0
            } else if m20 < -0.99999 {
                pitch = -.pi / 2
                yaw = atan2(m01, m11)
                roll = 0
            } else {
                pitch = asin(-m20)
                yaw = atan2(m10, m00)
                roll = atan2(m21, m22)
            }

            return vec3f(pitch, yaw, roll)
        }
        set {
            // Create rotation matrix from Euler angles (XYZ order)
            let cX = cos(newValue.x)
            let sX = sin(newValue.x)
            let cY = cos(newValue.y)
            let sY = sin(newValue.y)
            let cZ = cos(newValue.z)
            let sZ = sin(newValue.z)

            // Compute rotation matrix elements
            let m00 = cY * cZ
            let m01 = cY * sZ
            let m02 = -sY

            let m10 = sX * sY * cZ - cX * sZ
            let m11 = sX * sY * sZ + cX * cZ
            let m12 = sX * cY

            let m20 = cX * sY * cZ + sX * sZ
            let m21 = cX * sY * sZ - sX * cZ
            let m22 = cX * cY

            // Preserve scale and translation
            let scaleVec = self.scale
            let translationVec = self.translation

            // Apply rotations with scales
            columns.0.x = m00 * scaleVec.x
            columns.0.y = m10 * scaleVec.x
            columns.0.z = m20 * scaleVec.x

            columns.1.x = m01 * scaleVec.y
            columns.1.y = m11 * scaleVec.y
            columns.1.z = m21 * scaleVec.y

            columns.2.x = m02 * scaleVec.z
            columns.2.y = m12 * scaleVec.z
            columns.2.z = m22 * scaleVec.z

            // Restore translation
            self.translation = translationVec
        }
    }

    /// Gets or sets the rotation as Euler angles in degrees
    public var rotationDegrees: vec3f {
        get {
            rotation * (180 / .pi)
        }
        set {
            rotation = newValue * (.pi / 180)
        }
    }

    // MARK: Matrix Construction

    @inlinable
    public static func lookAt(eye: vec3f, target: vec3f, up: vec3f) -> mat4f {
        let zAxis = normalize(target - eye)
        let xAxis = normalize(cross(up, zAxis))
        let yAxis = cross(zAxis, xAxis)

        let viewMatrix = mat4f(
            vec4f(xAxis.x, yAxis.x, zAxis.x, 0),
            vec4f(xAxis.y, yAxis.y, zAxis.y, 0),
            vec4f(xAxis.z, yAxis.z, zAxis.z, 0),
            vec4f(-dot(xAxis, eye), -dot(yAxis, eye), -dot(zAxis, eye), 1)
        )

        return viewMatrix
            * mat4f(
                vec4f(1, 0, 0, 0),
                vec4f(0, 1, 0, 0),
                vec4f(0, 0, -1, 0),
                vec4f(0, 0, 0, 1)
            )
    }

    @inlinable
    public static func perspective(fovYRadians: Float, aspect: Float, nearZ: Float, farZ: Float)
        -> mat4f
    {
        let yScale = 1 / tan(fovYRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ

        return mat4f(
            vec4f(xScale, 0, 0, 0),
            vec4f(0, yScale, 0, 0),
            vec4f(0, 0, farZ / zRange, 1),
            vec4f(0, 0, -(farZ * nearZ) / zRange, 0)
        )
    }

    @inlinable
    public static func orthographic(
        left: Float, right: Float,
        bottom: Float, top: Float,
        nearZ: Float, farZ: Float
    ) -> mat4f {
        let width = right - left
        let height = top - bottom
        let depth = farZ - nearZ

        var result = mat4f.identity

        result.columns.0.x = 2 / width
        result.columns.1.y = 2 / height
        result.columns.2.z = -1 / depth

        result.columns.3.x = -(right + left) / width
        result.columns.3.y = -(top + bottom) / height
        result.columns.3.z = -nearZ / depth

        return result
    }

    @inlinable
    public init(rotationAbout axis: vec3f, byAngle angle: Float) {
        let axis = normalize(axis)
        let sinAngle = sin(angle)
        let cosAngle = cos(angle)
        let cosValue = 1.0 - cosAngle

        let x = axis.x
        let y = axis.y
        let z = axis.z

        self.init(
            vec4f(
                cosAngle + cosValue * x * x,
                cosValue * x * y + sinAngle * z,
                cosValue * x * z - sinAngle * y,
                0
            ),
            vec4f(
                cosValue * y * x - sinAngle * z,
                cosAngle + cosValue * y * y,
                cosValue * y * z + sinAngle * x,
                0
            ),
            vec4f(
                cosValue * z * x + sinAngle * y,
                cosValue * z * y - sinAngle * x,
                cosAngle + cosValue * z * z,
                0
            ),
            vec4f(0, 0, 0, 1)
        )
    }

    // MARK: Transformation Operations

    @inlinable
    public func rotate(_ rad: Float, axis: Axis) -> mat4f {
        let cosA = cos(rad)
        let sinA = sin(rad)

        var result = self
        switch axis {
        case .x:
            let rotX = mat4f(
                vec4f(1, 0, 0, 0),
                vec4f(0, cosA, sinA, 0),
                vec4f(0, -sinA, cosA, 0),
                vec4f(0, 0, 0, 1)
            )
            result = result * rotX
        case .y:
            let rotY = mat4f(
                vec4f(cosA, 0, -sinA, 0),
                vec4f(0, 1, 0, 0),
                vec4f(sinA, 0, cosA, 0),
                vec4f(0, 0, 0, 1)
            )
            result = result * rotY
        case .z:
            let rotZ = mat4f(
                vec4f(cosA, sinA, 0, 0),
                vec4f(-sinA, cosA, 0, 0),
                vec4f(0, 0, 1, 0),
                vec4f(0, 0, 0, 1)
            )
            result = result * rotZ
        }
        return result
    }

    @inlinable
    public func rotate(_ rad: Float, around center: vec3f, axis: Axis) -> mat4f {
        translate(center)
            .rotate(rad, axis: axis)
            .translate(-center)
    }

    @inlinable
    public func rotateDegrees(_ angle: Float, axis: Axis) -> mat4f {
        rotate(angle * .pi / 180, axis: axis)
    }

    @inlinable
    public func scale(_ scale: vec3f) -> mat4f {
        var result = self
        result.columns.0 *= scale.x
        result.columns.1 *= scale.y
        result.columns.2 *= scale.z
        return result
    }

    @inlinable
    public func scale(_ uniform: Float) -> mat4f {
        scale(vec3f(repeating: uniform))
    }

    public func translate(_ offset: vec3f) -> mat4f {
        let translation = mat4f(
            vec4f(1, 0, 0, 0),
            vec4f(0, 1, 0, 0),
            vec4f(0, 0, 1, 0),
            vec4f(offset.x, offset.y, offset.z, 1)
        )
        return self * translation
    }

    // MARK: Matrix Composition/Decomposition

    /// Decomposes the matrix into translation, rotation, and scale components
    public func decompose() -> (translation: vec3f, rotation: vec3f, scale: vec3f) {
        return (translation: self.translation, rotation: self.rotation, scale: self.scale)
    }

    /// Creates a matrix from translation, rotation, and scale components
    public static func compose(translation: vec3f, rotation: vec3f, scale: vec3f) -> mat4f {
        var matrix = mat4f.identity
        matrix.scale = scale
        matrix.rotation = rotation
        matrix.translation = translation
        return matrix
    }

    /// Creates a rotation matrix from Euler angles (in radians)
    public static func fromEuler(pitch: Float, yaw: Float, roll: Float) -> mat4f {
        var matrix = mat4f.identity
        matrix.rotation = vec3f(pitch, yaw, roll)
        return matrix
    }

    /// Creates a rotation matrix from Euler angles (in degrees)
    public static func fromEulerDegrees(pitch: Float, yaw: Float, roll: Float) -> mat4f {
        fromEuler(
            pitch: pitch * .pi / 180,
            yaw: yaw * .pi / 180,
            roll: roll * .pi / 180
        )
    }

    // MARK: Utility Functions

    @inlinable
    public func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
        Swift.min(Swift.max(value, min), max)
    }

    @inlinable
    public func inverse() -> mat4f {
        simd_inverse(self)
    }

    @inlinable
    public func transpose() -> mat4f {
        simd_transpose(self)
    }
}

// MARK: - Vector Extensions

extension vec3f {
    // NOTE: Common vector constants
    public static let zero = vec3f(0, 0, 0)
    public static let one = vec3f(1, 1, 1)
    public static let up = vec3f(0, 1, 0)
    public static let right = vec3f(1, 0, 0)
    public static let forward = vec3f(0, 0, 1)  // NOTE: Metal's coordinate system
}

extension SIMD2 {
    @inlinable public var xy: SIMD2<Scalar> { self }
    @inlinable public var yx: SIMD2<Scalar> { SIMD2(y, x) }

    @inlinable public var xx: SIMD2<Scalar> { SIMD2(x, x) }
    @inlinable public var yy: SIMD2<Scalar> { SIMD2(y, y) }
}

extension SIMD3 {
    // NOTE: 2D swizzles
    @inlinable public var xy: SIMD2<Scalar> { SIMD2(x, y) }
    @inlinable public var xz: SIMD2<Scalar> { SIMD2(x, z) }
    @inlinable public var yx: SIMD2<Scalar> { SIMD2(y, x) }
    @inlinable public var yz: SIMD2<Scalar> { SIMD2(y, z) }
    @inlinable public var zx: SIMD2<Scalar> { SIMD2(z, x) }
    @inlinable public var zy: SIMD2<Scalar> { SIMD2(z, y) }

    // NOTE: 3D swizzles
    @inlinable public var xyz: SIMD3<Scalar> { self }
    @inlinable public var xzy: SIMD3<Scalar> { SIMD3(x, z, y) }
    @inlinable public var yxz: SIMD3<Scalar> { SIMD3(y, x, z) }
    @inlinable public var yzx: SIMD3<Scalar> { SIMD3(y, z, x) }
    @inlinable public var zxy: SIMD3<Scalar> { SIMD3(z, x, y) }
    @inlinable public var zyx: SIMD3<Scalar> { SIMD3(z, y, x) }
}

extension SIMD4 {
    // NOTE: 2D swizzles
    @inlinable public var xy: SIMD2<Scalar> { SIMD2(x, y) }
    @inlinable public var xz: SIMD2<Scalar> { SIMD2(x, z) }
    @inlinable public var xw: SIMD2<Scalar> { SIMD2(x, w) }
    @inlinable public var yz: SIMD2<Scalar> { SIMD2(y, z) }
    @inlinable public var yw: SIMD2<Scalar> { SIMD2(y, w) }
    @inlinable public var zw: SIMD2<Scalar> { SIMD2(z, w) }

    // NOTE: 3D swizzles (common ones)
    @inlinable public var xyz: SIMD3<Scalar> { SIMD3(x, y, z) }
    @inlinable public var xyw: SIMD3<Scalar> { SIMD3(x, y, w) }
    @inlinable public var xzw: SIMD3<Scalar> { SIMD3(x, z, w) }
    @inlinable public var yzw: SIMD3<Scalar> { SIMD3(y, z, w) }

    // NOTE: 4D swizzles
    @inlinable public var xyzw: SIMD4<Scalar> { self }
}

// NOTE: CGSize to vec conversion
extension CGSize {
    public var asVec2i: vec2i {
        vec2i(Int32(width), Int32(height))
    }
}
