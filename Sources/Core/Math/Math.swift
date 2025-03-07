// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import simd

public typealias vec2u = SIMD2<UInt32>
public typealias vec3u = SIMD3<UInt32>
public typealias vec4u = SIMD4<UInt32>

public typealias vec2i = SIMD2<Int32>
public typealias vec3i = SIMD3<Int32>

public typealias vec2f = SIMD2<Float>
public typealias vec3f = SIMD3<Float>
public typealias vec4f = SIMD4<Float>

public typealias mat3f = simd_float3x3
public typealias mat4f = simd_float4x4

public enum Axis {
    case x, y, z
}

extension mat4f {
    public static var identity: mat4f {
        matrix_identity_float4x4
    }

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

    @inlinable
    public func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
        Swift.min(Swift.max(value, min), max)
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

    @inlinable
    public func inverse() -> mat4f {
        simd_inverse(self)
    }

    @inlinable
    public func transpose() -> mat4f {
        simd_transpose(self)
    }
}

//NOTE: For ease of use
extension vec3f {
    public static let zero = vec3f(0, 0, 0)
    public static let one = vec3f(1, 1, 1)
    public static let up = vec3f(0, 1, 0)
    public static let right = vec3f(1, 0, 0)
    public static let forward = vec3f(0, 0, 1)  // Metal's coordinate system
}

extension SIMD2 {
    @inlinable public var xy: SIMD2<Scalar> { self }
    @inlinable public var yx: SIMD2<Scalar> { SIMD2(y, x) }

    @inlinable public var xx: SIMD2<Scalar> { SIMD2(x, x) }
    @inlinable public var yy: SIMD2<Scalar> { SIMD2(y, y) }
}

extension SIMD3 {
    // 2D swizzles
    @inlinable public var xy: SIMD2<Scalar> { SIMD2(x, y) }
    @inlinable public var xz: SIMD2<Scalar> { SIMD2(x, z) }
    @inlinable public var yx: SIMD2<Scalar> { SIMD2(y, x) }
    @inlinable public var yz: SIMD2<Scalar> { SIMD2(y, z) }
    @inlinable public var zx: SIMD2<Scalar> { SIMD2(z, x) }
    @inlinable public var zy: SIMD2<Scalar> { SIMD2(z, y) }

    // 3D swizzles
    @inlinable public var xyz: SIMD3<Scalar> { self }
    @inlinable public var xzy: SIMD3<Scalar> { SIMD3(x, z, y) }
    @inlinable public var yxz: SIMD3<Scalar> { SIMD3(y, x, z) }
    @inlinable public var yzx: SIMD3<Scalar> { SIMD3(y, z, x) }
    @inlinable public var zxy: SIMD3<Scalar> { SIMD3(z, x, y) }
    @inlinable public var zyx: SIMD3<Scalar> { SIMD3(z, y, x) }
}

extension SIMD4 {
    // 2D swizzles
    @inlinable public var xy: SIMD2<Scalar> { SIMD2(x, y) }
    @inlinable public var xz: SIMD2<Scalar> { SIMD2(x, z) }
    @inlinable public var xw: SIMD2<Scalar> { SIMD2(x, w) }
    @inlinable public var yz: SIMD2<Scalar> { SIMD2(y, z) }
    @inlinable public var yw: SIMD2<Scalar> { SIMD2(y, w) }
    @inlinable public var zw: SIMD2<Scalar> { SIMD2(z, w) }

    // 3D swizzles (common ones)
    @inlinable public var xyz: SIMD3<Scalar> { SIMD3(x, y, z) }
    @inlinable public var xyw: SIMD3<Scalar> { SIMD3(x, y, w) }
    @inlinable public var xzw: SIMD3<Scalar> { SIMD3(x, z, w) }
    @inlinable public var yzw: SIMD3<Scalar> { SIMD3(y, z, w) }

    // 4D swizzles
    @inlinable public var xyzw: SIMD4<Scalar> { self }
}

//NOTE GCSize to vec
extension CGSize {
    public var asVec2i: vec2i {
        vec2i(Int32(width), Int32(height))
    }
}
