// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit

public class Time {
    let maxDelta: Double = 0.1
    private var previousTime: TimeInterval
    private var startTime: TimeInterval
    private(set) public var deltaTime: Double = 0.0
    private(set) public var totalTime: Double = 0.0
    public var deltaTimeFloat: Float { Float(deltaTime) }
    public var totalTimeFloat: Float { Float(totalTime) }
    var now: Float

    public init() {
        let initialTime = CACurrentMediaTime()
        self.previousTime = initialTime
        self.startTime = initialTime
        self.now = Float(CACurrentMediaTime())
    }

    public func update() {
        let currentTime = CACurrentMediaTime()
        let rawDelta = currentTime - previousTime
        deltaTime = min(rawDelta, maxDelta)
        totalTime = currentTime - startTime
        previousTime = currentTime
        now = Float(currentTime)
    }

    public func reset() {
        let newTime = CACurrentMediaTime()
        previousTime = newTime
        startTime = newTime
        deltaTime = 0.0
        totalTime = 0.0
    }
}
