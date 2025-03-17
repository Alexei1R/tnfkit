// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import simd

enum AnimationState {
    case stopped
    case playing
    case paused
}

class CustomAnimation {
    // Animation state
    private var recordedAnimation: CapturedAnimation?
    private var currentTime: TimeInterval = 0.0
    private var lastFrameTime: TimeInterval = 0.0
    private var state: AnimationState = .stopped
    private var isLooping: Bool = false  // Default to looping

    // Event system properties
    private var eventCallbacks: [AnimationEventCallback] = []

    // Animation control properties
    private var playbackSpeed: Float = 1.0
    private var isReversed: Bool = false

    // Animation event type
    enum AnimationEvent {
        case started
        case completed
        case looped
        case stopped
        case paused
        case resumed
    }

    // Callback type for animation events
    typealias AnimationEventCallback = (AnimationEvent) -> Void

    func play(animation: CapturedAnimation, startTime: TimeInterval = 0.0) {
        self.recordedAnimation = animation
        self.currentTime = startTime
        self.lastFrameTime = 0.0
        self.state = .playing
        notifyListeners(.started)
        print("Playing animation: \(animation.name)")
    }

    func pause() {
        guard state == .playing else { return }
        state = .paused
        notifyListeners(.paused)
        print("Animation paused")
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
        notifyListeners(.resumed)
        print("Animation resumed")
    }

    func stop() {
        recordedAnimation = nil
        currentTime = 0.0
        lastFrameTime = 0.0
        state = .stopped
        notifyListeners(.stopped)
        print("Animation stopped")
    }

    func setLooping(_ shouldLoop: Bool) {
        isLooping = shouldLoop
    }

    func update(deltaTime: TimeInterval) -> [mat4f] {
        guard let animation = recordedAnimation,
            !animation.frames.isEmpty,
            state == .playing
        else {
            return []
        }

        let adjustedDeltaTime = deltaTime * Double(playbackSpeed) * (isReversed ? -1 : 1)
        currentTime += adjustedDeltaTime
        let totalDuration = Double(animation.duration)

        if totalDuration > 0 {
            if currentTime >= totalDuration {
                if isLooping {
                    currentTime = currentTime.truncatingRemainder(dividingBy: totalDuration)
                    notifyListeners(.looped)
                } else {
                    currentTime = totalDuration
                    stop()
                    notifyListeners(.completed)
                    return animation.frames.last?.joints.map { $0.localTransform } ?? []
                }
            } else if currentTime < 0 {
                if isLooping {
                    currentTime =
                        totalDuration + currentTime.truncatingRemainder(dividingBy: totalDuration)
                    notifyListeners(.looped)
                } else {
                    currentTime = 0
                    stop()
                    notifyListeners(.completed)
                    return animation.frames.first?.joints.map { $0.localTransform } ?? []
                }
            }
        }

        let frameCount = animation.frames.count
        let progress = Float(currentTime / totalDuration)
        let exactFrame = progress * Float(frameCount - 1)
        let currentFrameIndex = Int(floor(exactFrame))
        let nextFrameIndex = min(currentFrameIndex + 1, frameCount - 1)
        let interpolationFactor = exactFrame - Float(currentFrameIndex)

        let currentFrame = animation.frames[currentFrameIndex]
        let nextFrame = animation.frames[nextFrameIndex]

        return interpolateJointMatrices(
            from: currentFrame.joints.map { $0.localTransform },
            to: nextFrame.joints.map { $0.localTransform },
            factor: interpolationFactor
        )
    }

    private func interpolateJointMatrices(from: [mat4f], to: [mat4f], factor: Float) -> [mat4f] {
        guard from.count == to.count else { return from }
        return zip(from, to).map { current, next in
            let currentRotation = simd_quatf(current)
            let nextRotation = simd_quatf(next)
            let currentTranslation = vec3f(
                current.columns.3.x, current.columns.3.y, current.columns.3.z)
            let nextTranslation = vec3f(next.columns.3.x, next.columns.3.y, next.columns.3.z)
            let interpolatedRotation = simd_slerp(currentRotation, nextRotation, factor)
            let interpolatedTranslation = mix(currentTranslation, nextTranslation, t: factor)
            var result = mat4f(interpolatedRotation)
            result.columns.3 = vec4f(
                interpolatedTranslation.x, interpolatedTranslation.y, interpolatedTranslation.z, 1)
            return result
        }
    }

    // Animation control methods
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = max(0.1, speed)
    }

    func setReversed(_ reversed: Bool) {
        isReversed = reversed
    }

    func toggleDirection() {
        isReversed = !isReversed
    }

    // Event system methods
    func addEventListener(_ callback: @escaping AnimationEventCallback) {
        eventCallbacks.append(callback)
    }

    func removeAllEventListeners() {
        eventCallbacks.removeAll()
    }

    private func notifyListeners(_ event: AnimationEvent) {
        eventCallbacks.forEach { callback in
            callback(event)
        }
    }

    // Helper methods
    func getProgress() -> Float {
        guard let animation = recordedAnimation,
            animation.duration > 0
        else {
            return 0
        }
        return Float(currentTime / Double(animation.duration))
    }

    var isPlaying: Bool {
        return state == .playing
    }

    var isPaused: Bool {
        return state == .paused
    }

    func getCurrentAnimation() -> CapturedAnimation? {
        return recordedAnimation
    }

    func seekTo(progress: Float) {
        guard let animation = recordedAnimation else { return }
        let clampedProgress = min(max(progress, 0), 1)
        currentTime = Double(clampedProgress) * Double(animation.duration)
    }

    func printTree() {
        guard let animation = recordedAnimation, let firstFrame = animation.frames.first
        else {
            print("No animation loaded")
            return
        }
        let joints = firstFrame.joints
        var childrenDict = [Int?: [CapturedJoint]]()
        for joint in joints {
            childrenDict[joint.parentIndex, default: []].append(joint)
        }
        func printJoint(_ joint: CapturedJoint, indent: String) {
            print("\(indent)\(joint.name) (id: \(joint.id))")
            if let children = childrenDict[joint.id] {
                for child in children {
                    printJoint(child, indent: indent + "  ")
                }
            }
        }
        if let roots = childrenDict[nil] {
            for root in roots {
                printJoint(root, indent: "")
            }
        }
    }

}
