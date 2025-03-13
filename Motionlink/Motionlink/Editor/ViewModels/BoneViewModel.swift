// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import SwiftUI

class BoneViewModel: ObservableObject {
    @Published var selectedAnimation: CapturedAnimation?
    @Published var showAnimationModal = false
    @Published var selectedBoneIndex: Int?
    @Published var animations: [CapturedAnimation] = []
    @Published var isLoading = false
    @Published var hierarchyItems: [BoneHierarchyItem] = []
    
    private let recordingManager = RecordingManager()
    
    init() {
        DispatchQueue.main.async {
            self.loadAnimations()
        }
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
    }
    
    func selectBone(_ index: Int) {
        self.selectedBoneIndex = index
    }
    
    func createHierarchy(from animation: CapturedAnimation) {
        guard let firstFrame = animation.frames.first else {
            hierarchyItems = []
            return
        }
        
        let joints = firstFrame.joints
        var hierarchyItems: [BoneHierarchyItem] = []
        
        let rootBones = joints.enumerated()
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
