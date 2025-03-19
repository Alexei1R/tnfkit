// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import SwiftUI
import Engine
import simd  // For matrix_float4x4 and related types

class BoneViewModel: NSObject, ObservableObject {
    @Published var selectedAnimation: CapturedAnimation?
    @Published var showAnimationModal = false
    @Published var selectedBoneIndex: Int?
    @Published var animations: [CapturedAnimation] = []
    @Published var isLoading = false
    @Published var hierarchyItems: [BoneHierarchyItem] = []
    @Published var isPlaying = false
    @Published var currentFrameIndex = 0
    @Published var assignmentFeedback = ""
    
    // Maps bone index to array of vertex indices
    @Published var boneVertexAssignments: [Int: [Int]] = [:]
    // Maps vertex index to bone index
    @Published var vertexBoneAssignments: [Int: Int] = [:]
    
    // Reference to the selectable model
    @Published var selectionModel: Any?
    private var animationTimer: Timer?
    
    private let recordingManager = RecordingManager()
    
    override init() {
        super.init()
        DispatchQueue.main.async {
            self.loadAnimations()
        }
    }
    
    @objc func setSelectionModel(_ model: Any) {
        print("🦴 BoneViewModel.setSelectionModel called with model: \(model)")
        self.selectionModel = model
    }
    
    func loadAnimations() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.recordingManager.loadSavedAnimations()
            
            DispatchQueue.main.async {
                self.animations = self.recordingManager.savedAnimations
                self.isLoading = false
                
                if let animation = self.selectedAnimation {
                    self.createHierarchy(from: animation)
                }
                
                if self.selectedAnimation == nil && !self.animations.isEmpty {
                    self.showAnimationModal = true
                }
            }
        }
    }
    
    var bones: [CapturedJoint] {
        guard let firstFrame = selectedAnimation?.frames.first else { return [] }
        return firstFrame.joints
    }
    
    func selectAnimation(_ animation: CapturedAnimation) {
        self.selectedAnimation = animation
        self.selectedBoneIndex = nil
        self.showAnimationModal = false
        createHierarchy(from: animation)
        
        // Reset assignments when changing animations
        boneVertexAssignments = [:]
        vertexBoneAssignments = [:]
        
        // Reset visual joint colors in the 3D model
        if let model = selectionModel as? NSObject, model.responds(to: #selector(NSObject.clearJointAssignments)) {
            print("🦴 Clearing visual joint assignments")
            model.clearJointAssignments()
        }
        
        stopAnimation()
        currentFrameIndex = 0
    }
    
    func selectBone(_ index: Int) {
        self.selectedBoneIndex = index
    }
    
    func assignSelectedVerticesToBone() {
        print("🦴 assignSelectedVerticesToBone called")
        
        guard let selectedBoneIndex = selectedBoneIndex else {
            print("🦴 No bone selected")
            assignmentFeedback = "No bone selected"
            return
        }
        
        // Force unwrap and check if the value is there (handles both nil and Optional.none cases)
        if let unwrappedModel = selectionModel {
            print("🦴 selectionModel available: \(unwrappedModel)")
        } else {
            print("🦴 No model available")
            assignmentFeedback = "No model available"
            return
        }
        
        // Get the unwrapped model value
        let model = selectionModel!
        
        print("🦴 Getting model methods...")
        
        // Get selected vertices using NSObject dynamic method calls for safety
        let nsModel = model as AnyObject
        print("🦴 Model as AnyObject: \(nsModel)")
        
        if nsModel.responds(to: #selector(NSObject.value(forKey:))) {
            print("🦴 Model responds to value(forKey:)")
            
            // First try to call getSelectedVertexIndices directly
            if nsModel.responds(to: #selector(NSObject.getSelectedVertexIndices)) {
                print("🦴 Model responds to getSelectedVertexIndices directly")
                
                if let selectedVertices = nsModel.perform(#selector(NSObject.getSelectedVertexIndices))?.takeUnretainedValue() as? [Int] {
                    handleSelectedVertices(selectedVertices, selectedBoneIndex)
                    return
                }
            }
            
            // Otherwise try using KVC
            if let selectedVerticesMethod = nsModel.value(forKey: "getSelectedVertexIndices") {
                print("🦴 Got method reference: \(selectedVerticesMethod)")
                
                if let method = selectedVerticesMethod as? () -> [Int] {
                    print("🦴 Cast method to function pointer")
                    let selectedVertices = method()
                    handleSelectedVertices(selectedVertices, selectedBoneIndex)
                    return
                } else {
                    print("🦴 Method is not a function pointer: \(type(of: selectedVerticesMethod))")
                }
            } else {
                print("🦴 Could not get getSelectedVertexIndices via KVC")
            }
        }
        
        // If we get here, all approaches failed
        print("🦴 All approaches to get vertices failed")
        assignmentFeedback = "Cannot access selection method"
    }
    
    private func handleSelectedVertices(_ selectedVertices: [Int], _ selectedBoneIndex: Int) {
        print("🦴 Got \(selectedVertices.count) selected vertices")
        
        if selectedVertices.isEmpty {
            assignmentFeedback = "No vertices selected"
            return
        }
        
        // Remove these vertices from any previous bone assignments
        for vertexIndex in selectedVertices {
            if let oldBoneIndex = vertexBoneAssignments[vertexIndex] {
                boneVertexAssignments[oldBoneIndex]?.removeAll(where: { $0 == vertexIndex })
            }
            
            // Assign to new bone
            vertexBoneAssignments[vertexIndex] = selectedBoneIndex
        }
        
        // Create or update the array for this bone
        if boneVertexAssignments[selectedBoneIndex] == nil {
            boneVertexAssignments[selectedBoneIndex] = selectedVertices
        } else {
            boneVertexAssignments[selectedBoneIndex]?.append(contentsOf: selectedVertices)
            // Remove duplicates
            boneVertexAssignments[selectedBoneIndex] = Array(Set(boneVertexAssignments[selectedBoneIndex]!))
        }
        
        // Update the visual representation in the 3D model
        if let model = selectionModel as? NSObject {
            // Call the assignJointToVertices method if it exists
            if model.responds(to: #selector(NSObject.assignJointToVertices(vertexIndices:jointIndex:))) {
                print("🦴 Visually assigning joint \(selectedBoneIndex) to \(selectedVertices.count) vertices")
                let success = model.assignJointToVertices(vertexIndices: selectedVertices, jointIndex: selectedBoneIndex)
                if success {
                    print("🦴 Visual joint assignment successful")
                    
                    // Clear the selection after assigning to make the joint colors visible
                    if model.responds(to: #selector(NSObject.clearSelection)) {
                        print("🦴 Clearing selection to make joint colors visible")
                        model.clearSelection()
                    }
                } else {
                    print("🦴 Visual joint assignment failed")
                }
            } else {
                print("🦴 Model doesn't support visual joint assignment")
            }
        }
        
        print("🦴 Assignment successful: \(selectedVertices.count) vertices to bone \(selectedBoneIndex)")
        assignmentFeedback = "Assigned \(selectedVertices.count) vertices to \(bones[selectedBoneIndex].name)"
        
        // Notify that we've updated the assignments
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.assignmentFeedback = ""
        }
    }
    
    func getAssignmentCountForBone(_ boneIndex: Int) -> Int {
        return boneVertexAssignments[boneIndex]?.count ?? 0
    }
    
    func playAnimation() {
        print("▶️ Play animation called")
        
        guard let animation = selectedAnimation, !animation.frames.isEmpty else {
            print("▶️ No animation or empty frames")
            return
        }
        
        print("▶️ Animation has \(animation.frames.count) frames, starting playback")
        
        stopAnimation()
        isPlaying = true
        currentFrameIndex = 0
        
        // Calculate interval based on frame rate
        let interval = 1.0 / Double(animation.frameRate)
        print("▶️ Using interval: \(interval) seconds (frame rate: \(animation.frameRate))")
        
        // Create timer for animation playback
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let animation = self.selectedAnimation else {
                print("▶️ Animation or self became nil during playback")
                self?.stopAnimation()
                return
            }
            
            // Update frame index
            self.currentFrameIndex = (self.currentFrameIndex + 1) % animation.frames.count
            
            // Log progress occasionally
            if self.currentFrameIndex % 10 == 0 {
                print("▶️ Animation at frame \(self.currentFrameIndex)/\(animation.frames.count)")
            }
            
            // Apply bone transforms to vertices
            self.applyAnimationFrame(frameIndex: self.currentFrameIndex)
        }
        
        print("▶️ Animation timer started")
    }
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isPlaying = false
    }
    
    func applyAnimationFrame(frameIndex: Int) {
        // Only log occasionally to avoid flooding the console
        let shouldLog = frameIndex % 30 == 0
        if shouldLog {
            print("🎬 Applying animation frame \(frameIndex)")
        }
        
        guard let animation = selectedAnimation,
              frameIndex < animation.frames.count else {
            if shouldLog {
                print("🎬 Invalid animation or frame index")
            }
            return
        }
        
        guard let unwrappedModel = selectionModel else {
            if shouldLog {
                print("🎬 No model available")
            }
            return
        }
        
        // Log some info on first frame
        if frameIndex == 0 {
            print("🎬 Animation \(animation.name) has \(animation.frames.count) frames")
            print("🎬 Bone assignments: \(boneVertexAssignments)")
        }
        
        let model = unwrappedModel
        
        let frame = animation.frames[frameIndex]
        
        if shouldLog {
            print("🎬 Frame has \(frame.joints.count) joints")
            print("🎬 Have \(boneVertexAssignments.count) bone-vertex assignments")
        }
        
        // Apply joint transforms to assigned vertices
        var totalVerticesAnimated = 0
        
        // First, collect all the vertices that have assignments
        var assignedVertices = Set<Int>()
        for (_, vertexIndices) in boneVertexAssignments {
            for index in vertexIndices {
                assignedVertices.insert(index)
            }
        }
        
        // Get the root bone transform (assuming bone index 0 is the root)
        let rootBoneTransform: matrix_float4x4
        if frame.joints.count > 0 {
            rootBoneTransform = frame.joints[0].transform
        } else {
            rootBoneTransform = matrix_identity_float4x4  // Built-in Metal identity matrix
        }
        
        // Process assigned vertices first
        for (boneIndex, vertexIndices) in boneVertexAssignments {
            if boneIndex < frame.joints.count {
                let boneTransform = frame.joints[boneIndex].transform
                totalVerticesAnimated += vertexIndices.count
                
                if shouldLog && !vertexIndices.isEmpty {
                    print("🎬 Would animate \(vertexIndices.count) vertices for bone \(boneIndex)")
                }
                
                // Apply transformation to all assigned vertices
                let nsModel = model as AnyObject
                if nsModel.responds(to: #selector(NSObject.updateVertexPosition(index:transform:))) {
                    // Apply to all vertices assigned to this bone - but limit count for performance
                    // This will demonstrate the animation effect without trying to process too many vertices
                    let maxVerticesToProcess = min(vertexIndices.count, 200)
                    var processedCount = 0
                    
                    for vertexIndex in vertexIndices.prefix(maxVerticesToProcess) {
                        // Safely call the method and ignore any errors
                        do {
                            let _ = nsModel.perform(#selector(NSObject.updateVertexPosition(index:transform:)), 
                                       with: NSNumber(value: vertexIndex), 
                                       with: boneTransform)
                            processedCount += 1
                        } catch {
                            if shouldLog {
                                print("🎬 Error animating vertex \(vertexIndex): \(error)")
                            }
                        }
                    }
                    
                    if shouldLog {
                        print("🎬 Applied transform to \(processedCount)/\(vertexIndices.count) vertices for bone \(boneIndex)")
                    }
                }
            }
        }
        
        // For safety, we'll use a simplified approach for unassigned vertices
        // Apply root transform to just a few sample vertices to demonstrate the capability
        
        // Use a fixed count for demo purposes - this avoids having to call getTotalVertexCount
        let sampleUnassignedVertices = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
        var unassignedCount = 0
        
        // Access the model again to make sure it's in scope
        let nsModel = model as AnyObject
        
        // Apply to a small set of vertices to demonstrate
        for vertexIndex in sampleUnassignedVertices {
            if !assignedVertices.contains(vertexIndex) {
                // Safely apply animation to this vertex
                if nsModel.responds(to: #selector(NSObject.updateVertexPosition(index:transform:))) {
                    do {
                        let _ = nsModel.perform(#selector(NSObject.updateVertexPosition(index:transform:)),
                                    with: NSNumber(value: vertexIndex),
                                    with: rootBoneTransform)
                        unassignedCount += 1
                    } catch {
                        // Simply ignore errors for sample vertices
                        if shouldLog {
                            print("🎬 Error animating sample vertex \(vertexIndex)")
                        }
                    }
                }
            }
        }
        
        totalVerticesAnimated += unassignedCount
        
        if shouldLog && unassignedCount > 0 {
            print("🎬 Applied root transform to \(unassignedCount) sample unassigned vertices")
        }
        
        if shouldLog && totalVerticesAnimated > 0 {
            print("🎬 Animated a total of \(totalVerticesAnimated) vertices this frame")
        }
    }
    
    func createHierarchy(from animation: CapturedAnimation) {
        guard let firstFrame = animation.frames.first else {
            hierarchyItems = []
            return
        }
        
        let joints = firstFrame.joints
        var hierarchyItems: [BoneHierarchyItem] = []
        
        _ = joints.enumerated()
            .filter { $0.element.parentIndex == nil || $0.element.parentIndex == -1 }
            .map { $0.offset }
        
        var lastParentIndex = -1
        
        for i in 0..<joints.count {
            let joint = joints[i]
            let parentIndex = joint.parentIndex ?? -1
            
            var depth = 0
            var currentParent = parentIndex
            var visited = Set<Int>()
            
            while currentParent >= 0 && currentParent < joints.count && !visited.contains(currentParent) && depth < 10 {
                depth += 1
                visited.insert(currentParent)
                currentParent = joints[currentParent].parentIndex ?? -1
            }
            
            let isIndexReset = parentIndex >= 0 && i > 0 &&
                              (parentIndex < i - 5 ||
                               (lastParentIndex > 0 && parentIndex < lastParentIndex - 5))
            
            hierarchyItems.append(BoneHierarchyItem(
                id: i,
                joint: joint,
                depth: min(depth, 10),
                isLastInBranch: !joints.contains(where: { $0.parentIndex == i }),
                isRootBone: parentIndex < 0,
                isIndexReset: isIndexReset
            ))
            
            if parentIndex >= 0 {
                lastParentIndex = parentIndex
            }
        }
        
        self.hierarchyItems = hierarchyItems
    }
}

struct BoneHierarchyItem: Identifiable {
    let id: Int
    let joint: CapturedJoint
    let depth: Int
    let isLastInBranch: Bool
    let isRootBone: Bool
    let isIndexReset: Bool
    
    var dotColor: Color {
        if isIndexReset {
            return .orange
        } else if isRootBone {
            return .red
        } else if depth >= 3 {
            return .blue
        } else {
            return .green
        }
    }
}

// MARK: - Objective-C Method Declarations for Model Interface
extension NSObject {
    // These methods are declared here to support #selector but are implemented in SelectableModel
    @objc func getSelectedVertexIndices() -> [Int] { return [] }
    @objc func getTotalVertexCount() -> Int { return 0 }
    @objc func updateVertexPosition(index: Int, transform: matrix_float4x4) {}
    @objc func assignJointToVertices(vertexIndices: [Int], jointIndex: Int) -> Bool { return false }
    @objc func getJointIndexForVertex(vertexIndex: Int) -> Int { return -1 }
    @objc func clearJointAssignments() {}
    @objc func clearSelection() {}
}
