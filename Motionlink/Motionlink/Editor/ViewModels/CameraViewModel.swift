//
//  CameraViewModel.swift
//  Motionlink
//
//  Created by rusu alexei on 11.03.2025.
//

import ARKit
import Combine
import Foundation
import MetalKit

final class CameraViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingName: String = "default"
    private var animRecorder: RecordingManager = RecordingManager()
    private var capturedAnimation: CapturedAnimation
    private var recordingStartTime: TimeInterval = 0

    init() {
        self.capturedAnimation = CapturedAnimation(
            name: "default",
            frames: [],
            duration: 0,
            frameRate: 60.0,
            recordingDate: Date()
        )
    }

    func startRecording() {
        // Reset animation with current name
        capturedAnimation = CapturedAnimation(
            name: recordingName,
            frames: [],
            duration: 0,
            frameRate: 60.0,
            recordingDate: Date()
        )

        // Set the recording start time
        recordingStartTime = Date().timeIntervalSince1970

        print("===== Recording started =====")
    }

    func endRecording() {
        // Calculate final duration
        if !capturedAnimation.frames.isEmpty {
            let endTime = Date().timeIntervalSince1970
            capturedAnimation.duration = endTime - recordingStartTime
        }

        print("===== Recording ended - \(capturedAnimation.frames.count) frames captured =====")
    }

    func saveRecording(name: String) {
        // Update animation name before saving
        capturedAnimation.name = name.isEmpty ? "unnamed_recording" : name

        // Save the animation with captured frames
        animRecorder.saveAnimation(capturedAnimation)

        capturedAnimation = CapturedAnimation(
            name: "default",
            frames: [],
            duration: 0,
            frameRate: 60.0,
            recordingDate: Date()
        )

        print(
            "===== Animation saved: \(name) with \(capturedAnimation.frames.count) frames and \(String(format: "%.2f", capturedAnimation.duration))s duration ====="
        )
    }

    func handleBodyTracking(bodyAnchor: ARBodyAnchor) {
        // Only capture frames when recording is active
        guard isRecording else { return }

        // Create joints from skeleton data
        let joints: [CapturedJoint] = bodyAnchor.skeleton.jointModelTransforms.enumerated()
            .compactMap { (index, transform) in
                // Get the joint name as a string
                let jointNameString = bodyAnchor.skeleton.definition.jointNames[index]

                // Try to create a JointName from the string
                // Fix: Create an explicit optional variable first
                let optionalJointName: ARSkeleton.JointName? = ARSkeleton.JointName(
                    rawValue: jointNameString)
                if let jointName = optionalJointName,
                    let localTransform = bodyAnchor.skeleton.localTransform(for: jointName)
                {

                    return CapturedJoint(
                        id: index,
                        name: jointName.rawValue,
                        transform: transform,
                        localTransform: localTransform,
                        parentIndex: bodyAnchor.skeleton.definition.parentIndices[index]
                    )
                }
                return nil
            }

        // Calculate frame timestamp relative to recording start
        let currentTime = Date().timeIntervalSince1970
        let relativeTimestamp = currentTime - recordingStartTime

        // Create frame
        let captureFrame = CapturedFrame(
            id: capturedAnimation.frames.count,
            joints: joints,
            timestamp: relativeTimestamp,
            bodyTransform: bodyAnchor.transform
        )

        // Append frame to captured animation
        capturedAnimation.frames.append(captureFrame)

        // Update animation duration as we record
        capturedAnimation.duration = relativeTimestamp
    }

    func handleFrame(frame: ARFrame) {
        // Process camera frame if needed
        // This could be used for additional processing or visual feedback
    }
}
