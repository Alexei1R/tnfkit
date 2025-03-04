// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Combine
import Core
import Foundation
import MetalKit

@MainActor
public class SelectionTool: ToolInterfaceProtocol {

    // Core properties
    private var selectionPoints: [vec2f] = []
    public var isActive: Bool = false
    private let distanceThreshold: Float = 0.005

    // Point count threshold for onChange callback
    private var pointCountThreshold: Int = 1
    private var lastCallbackPointCount: Int = 0

    // Callbacks
    public typealias SelectionCompletionHandler = ([vec2f]) -> Void
    public typealias SelectionChangeHandler = ([vec2f]) -> Void

    private var onSelectionComplete: SelectionCompletionHandler?
    private var onSelectionChange: SelectionChangeHandler?

    // Event handling
    private let eventPublisher = EventPublisher.shared
    private var cancellables = Set<AnyCancellable>()

    public init(
        pointCountThreshold: Int = 5,
        onSelectionComplete: SelectionCompletionHandler? = nil,
        onSelectionChange: SelectionChangeHandler? = nil
    ) {
        self.pointCountThreshold = pointCountThreshold
        self.onSelectionComplete = onSelectionComplete
        self.onSelectionChange = onSelectionChange
        setupEventHandlers()
    }

    // Set or update callbacks after initialization
    public func setSelectionCompletionHandler(_ handler: @escaping SelectionCompletionHandler) {
        self.onSelectionComplete = handler
    }

    public func setSelectionChangeHandler(_ handler: @escaping SelectionChangeHandler) {
        self.onSelectionChange = handler
    }

    public func setPointCountThreshold(_ threshold: Int) {
        self.pointCountThreshold = max(1, threshold)
    }

    private func setupEventHandlers() {
        eventPublisher.touchEvents
            .sink { [weak self] event in

                Task { @MainActor [weak self] in

                    guard let self = self, self.isActive else { return }

                    switch event {
                    case .began(let touches), .moved(let touches):
                        if let position = touches.first?.position {
                            self.addPoint(position)
                            self.checkPointThreshold()
                        }
                    case .ended:
                        self.finishSelection()
                    case .cancelled:
                        self.clear()
                    }
                }
            }
            .store(in: &cancellables)

        eventPublisher.dragEvents
            .sink { [weak self] event in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isActive else { return }

                    if case .drag(_, _, let state, let position) = event {
                        switch state {
                        case .began, .changed:

                            Log.error(position)
                            self.addPoint(position)
                            self.checkPointThreshold()
                        case .ended:
                            self.finishSelection()
                        case .cancelled:
                            self.clear()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func addPoint(_ point: vec2f) {
        if let lastPoint = selectionPoints.last {
            let dx = point.x - lastPoint.x
            let dy = point.y - lastPoint.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance >= distanceThreshold {
                selectionPoints.append(point)
            }
        } else {
            selectionPoints.append(point)
        }
    }

    private func checkPointThreshold() {
        let currentCount = selectionPoints.count
        if currentCount >= lastCallbackPointCount + pointCountThreshold {
            onSelectionChange?(selectionPoints)
            lastCallbackPointCount = currentCount
            print("Selection changed: now \(currentCount) points")
        }
    }

    private func finishSelection() {
        if !selectionPoints.isEmpty {
            print("Selection finalized with \(selectionPoints.count) points")
            onSelectionComplete?(selectionPoints)
        }
        selectionPoints.removeAll()
        lastCallbackPointCount = 0
    }

    // MARK: - ToolInterfaceProtocol Methods
    public func onSelected() {
        isActive = true
        selectionPoints.removeAll()
        lastCallbackPointCount = 0
        print("Selection tool activated")
    }

    public func onDeselected() {
        isActive = false
        print("Selection tool deactivated")
    }

    public func onUpdate() {
    }

    // Additional ool-specific methods
    private func clear() {
        selectionPoints.removeAll()
        lastCallbackPointCount = 0
    }

    public func getSelectionPoints() -> [vec2f] {
        return selectionPoints
    }

}

//Array extension to convert the points to ndc
extension Array where Element == vec2f {
    public func toNDC() -> [vec2f] {
        return self.map { point in
            // convert to [-1,1] range
            let ndcX = point.x * 2.0 - 1.0
            let ndcY = 1.0 - point.y * 2.0

            return vec2f(x: ndcX, y: ndcY)
        }
    }
}
