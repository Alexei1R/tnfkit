//
//  BoneAssign.swift
//  Motionlink
//
//  Created by rusu alexei on 13.03.2025.
//

import Foundation
import SwiftUI

class BoneAssignViewModel: ObservableObject {
    @Published var selectedAnimation: CapturedAnimation?
    @Published var showAnimationModal = false
    @Published var selectedBoneIndex: Int?
    @Published var animations: [CapturedAnimation] = []
    
    private let recordingManager = RecordingManager()
    
    init() {
        loadAnimations()
    }
    
    func loadAnimations() {
        recordingManager.loadSavedAnimations()
        self.animations = recordingManager.savedAnimations
    }
    
    func getBonesFromAnimation(_ animation: CapturedAnimation?) -> [CapturedJoint] {
        guard let firstFrame = animation?.frames.first else { return [] }
        return firstFrame.joints
    }
    
    func selectAnimation(_ animation: CapturedAnimation) {
        self.selectedAnimation = animation
        self.selectedBoneIndex = nil
        self.showAnimationModal = false
    }
    
    func selectBone(_ index: Int) {
        self.selectedBoneIndex = index
    }
}

struct BoneAssign: View {
    @StateObject private var viewModel = BoneAssignViewModel()
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main content
            VStack(spacing: 6) {
                // Bones header (simplified)
                if let animation = viewModel.selectedAnimation {
                    HStack {
                        Text("Bones in \"\(animation.name)\"")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(viewModel.getBonesFromAnimation(animation).count)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    
                    // Bones list view
                    bonesListView
                } else {
                    // No animation selected view
                    VStack(spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                        
                        Text("No animation selected")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 2)
            
            // Floating animation select button (now just an icon)
            Button(action: {
                viewModel.showAnimationModal = true
            }) {
                Image(systemName: "film")
                    .font(.system(size: 14))
                    .padding(10)
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 3)
            }
            .padding(12)
            
            // Animation selection modal
            if viewModel.showAnimationModal {
                animationSelectionModal
            }
        }
    }
    
    // MARK: - View Components
    
    private var bonesListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let animation = viewModel.selectedAnimation {
                // Bones list
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(viewModel.getBonesFromAnimation(animation).enumerated()), id: \.element.id) { index, joint in
                            BoneRow(
                                joint: joint,
                                isSelected: viewModel.selectedBoneIndex == index,
                                onSelect: {
                                    viewModel.selectBone(index)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // Bottom info
                if let selectedIndex = viewModel.selectedBoneIndex,
                   let joints = animation.frames.first?.joints,
                   selectedIndex < joints.count {
                    let joint = joints[selectedIndex]
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected: \(joint.name)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Ready for vertex assignment")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    // Modal overlay with animation selection
    private var animationSelectionModal: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        viewModel.showAnimationModal = false
                    }
                }
            
            // Modal content
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Select Animation")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            viewModel.showAnimationModal = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 8)
                
                if viewModel.animations.isEmpty {
                    // No animations view
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundColor(.yellow)
                            .padding(.top, 20)
                        
                        Text("No animations found")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        
                        Text("Record an animation first")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                        
                        Button(action: {
                            viewModel.loadAnimations()
                        }) {
                            Text("Refresh")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue)
                                )
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                } else {
                    // Animation list
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.animations) { animation in
                                AnimationRow(
                                    animation: animation,
                                    isSelected: viewModel.selectedAnimation?.id == animation.id,
                                    onSelect: {
                                        viewModel.selectAnimation(animation)
                                    }
                                )
                                .padding(.horizontal, 12)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 300)
                    
                    // Bottom buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation {
                                viewModel.showAnimationModal = false
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                )
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            viewModel.loadAnimations()
                        }) {
                            Text("Refresh")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue)
                                )
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .frame(width: 300)
            .shadow(color: Color.black.opacity(0.5), radius: 20)
        }
        .transition(.opacity)
    }
}

struct AnimationRow: View {
    let animation: CapturedAnimation
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.5), lineWidth: 1)
                    )
                
                // Animation info
                VStack(alignment: .leading, spacing: 2) {
                    Text(animation.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text("\(animation.frames.count) frames")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("\(String(format: "%.1f", animation.duration))s")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BoneRow: View {
    let joint: CapturedJoint
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                
                // Joint name
                Text(joint.name)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(1)
                
                Spacer()
                
                // Parent info (more compact)
                if let parentIndex = joint.parentIndex {
                    Text("P:\(parentIndex)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .padding(.trailing, 4) // Added small padding on the right side
            .background(
                isSelected ? Color.blue.opacity(0.2) : Color.clear
            )
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
