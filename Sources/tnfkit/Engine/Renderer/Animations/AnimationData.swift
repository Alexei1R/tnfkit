// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import simd

/// Represents a single joint in the skeletal hierarchy
public struct CapturedJoint: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let transform: simd_float4x4
    public let localTransform: simd_float4x4
    public let parentIndex: Int?

    public init(
        id: Int,
        name: String,
        transform: simd_float4x4,
        localTransform: simd_float4x4,
        parentIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.transform = transform
        self.localTransform = localTransform
        self.parentIndex = parentIndex
    }
}

/// Represents a complete frame of skeletal animation data
public struct CapturedFrame: Codable, Identifiable {
    public let id: Int
    public var joints: [CapturedJoint]
    public var timestamp: TimeInterval
    public var bodyTransform: simd_float4x4

    public init(
        id: Int,
        joints: [CapturedJoint],
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        bodyTransform: simd_float4x4 = simd_float4x4(1.0)
    ) {
        self.id = id
        self.joints = joints
        self.timestamp = timestamp
        self.bodyTransform = bodyTransform
    }
}

/// Represents a complete animation sequence
public struct CapturedAnimation: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var name: String
    public var frames: [CapturedFrame]
    public var duration: Double
    public var frameRate: Float
    public var recordingDate: Date

    public init(
        name: String,
        frames: [CapturedFrame],
        duration: Double,
        frameRate: Float = 30.0,
        recordingDate: Date = Date()
    ) {
        self.name = name
        self.frames = frames
        self.duration = duration
        self.frameRate = frameRate
        self.recordingDate = recordingDate
    }

    public static func == (lhs: CapturedAnimation, rhs: CapturedAnimation) -> Bool {
        return lhs.id == rhs.id
    }
}

// NOTE: - Matrix Extensions
/// Extension to make simd_float4x4 Codable
extension simd_float4x4: Codable {
    public enum CodingKeys: String, CodingKey {
        case columns
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let array = [columns.0, columns.1, columns.2, columns.3]
        try container.encode(array, forKey: .columns)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let array = try container.decode([SIMD4<Float>].self, forKey: .columns)

        guard array.count == 4 else {
            throw DecodingError.dataCorruptedError(
                forKey: .columns,
                in: container,
                debugDescription: "Invalid matrix size")
        }

        self.init(array[0], array[1], array[2], array[3])
    }
}

