// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import simd

/// Represents a single joint in the skeletal hierarchy
struct CapturedJoint: Codable, Identifiable {
    let id: Int
    let name: String
    let path: String
    let transform: simd_float4x4
    let localTransform: simd_float4x4
    let parentIndex: Int?

    init(
        id: Int,
        name: String,
        path: String = "",
        transform: simd_float4x4,
        localTransform: simd_float4x4,
        parentIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.transform = transform
        self.localTransform = localTransform
        self.parentIndex = parentIndex
    }
}

/// Represents a complete frame of skeletal animation data
struct CapturedFrame: Codable, Identifiable {
    let id: Int
    var joints: [CapturedJoint]
    var timestamp: TimeInterval
    var bodyTransform: simd_float4x4

    init(
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
struct CapturedAnimation: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var frames: [CapturedFrame]
    var duration: Double
    var frameRate: Float
    var recordingDate: Date

    init(
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

    static func == (lhs: CapturedAnimation, rhs: CapturedAnimation) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Matrix Extensions

/// Extension to make simd_float4x4 Codable
extension simd_float4x4: Codable {
    enum CodingKeys: String, CodingKey {
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
