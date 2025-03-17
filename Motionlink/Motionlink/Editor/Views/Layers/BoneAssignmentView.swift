// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import SwiftUI
import simd
import tnfkit

struct BoneAssignmentView: View {
    @StateObject private var viewModel = BoneViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 6) {
                if let animation = viewModel.selectedAnimation {
                    HStack {
                        Text("Bones in \"\(animation.name)\"")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        Text("\(viewModel.bones.count)")
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

                    BoneHierarchyView(viewModel: viewModel)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)

                        Text("No animation selected")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)

                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .padding(.top, 8)
                        } else {
                            Button(action: {
                                viewModel.showAnimationModal = true
                            }) {
                                Text("Select Animation")
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .padding(.top, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 20)
                    .onAppear {
                        if viewModel.selectedAnimation == nil && !viewModel.isLoading {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                viewModel.showAnimationModal = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)

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
            .padding(.trailing, 5)

            if viewModel.showAnimationModal {
                AnimationSelectionModal(viewModel: viewModel)
            }
        }
    }
}

struct BoneHierarchyView: View {
    @ObservedObject var viewModel: BoneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(viewModel.hierarchyItems) { item in
                        HierarchyBoneRow(
                            hierarchyItem: item,
                            isSelected: viewModel.selectedBoneIndex == item.id,
                            onSelect: {
                                viewModel.selectBone(item.id)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            if let selectedIndex = viewModel.selectedBoneIndex,
                selectedIndex < viewModel.bones.count
            {

                let joint = viewModel.bones[selectedIndex]

                HStack(spacing: 8) {
                    Button(action: {
                    }) {
                        Text("Assign")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(joint.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)

                        if let parentIndex = joint.parentIndex,
                            parentIndex >= 0,
                            parentIndex < viewModel.bones.count
                        {
                            Text("Parent: \(viewModel.bones[parentIndex].name)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        } else {
                            Text("Root bone")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
    }
}

struct HierarchyBoneRow: View {
    let hierarchyItem: BoneHierarchyItem
    let isSelected: Bool
    let onSelect: () -> Void

    private let tabWidth: CGFloat = 8

    private var effectiveDepth: Int {
        min(hierarchyItem.depth, 5)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 2)

                if effectiveDepth > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<effectiveDepth, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1)
                                .padding(.leading, tabWidth - 1)
                        }
                    }
                }

                Circle()
                    .fill(hierarchyItem.dotColor)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 4)
                    .padding(.leading, 2)

                Text(hierarchyItem.joint.name)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(1)

                Spacer()

                if let parentIndex = hierarchyItem.joint.parentIndex,
                    parentIndex >= 0
                {
                    Text("↑\(parentIndex)")
                        .font(.system(size: 9))
                        .foregroundColor(hierarchyItem.isIndexReset ? .orange : .gray.opacity(0.7))
                        .padding(.trailing, 30)
                }
            }
            .padding(.vertical, 4)
            .padding(.leading, 6)
            .padding(.trailing, 4)
            .background(
                isSelected ? Color.blue.opacity(0.2) : Color.clear
            )
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AnimationSelectionModal: View {
    @ObservedObject var viewModel: BoneViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        viewModel.showAnimationModal = false
                    }
                }

            VStack(spacing: 8) {
                HStack {
                    Text("Select Animation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        withAnimation {
                            viewModel.showAnimationModal = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 12)

                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 8)

                if viewModel.isLoading {
                    AnimationLoadingView()
                } else if viewModel.animations.isEmpty {
                    EmptyAnimationsView(onRefresh: { viewModel.loadAnimations() })
                } else {
                    AnimationsScrollView(
                        animations: viewModel.animations,
                        selectedAnimation: viewModel.selectedAnimation,
                        onSelectAnimation: { viewModel.selectAnimation($0) }
                    )

                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation {
                                viewModel.showAnimationModal = false
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.3))
                                )
                                .foregroundColor(.white)
                        }

                        Button(action: {
                            viewModel.loadAnimations()
                        }) {
                            Text("Refresh")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue)
                                )
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .frame(width: 260)
            .shadow(color: Color.black.opacity(0.5), radius: 20)
        }
        .transition(.opacity)
    }
}

struct AnimationLoadingView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.8)

            Text("Loading animations...")
                .foregroundColor(.gray)
                .font(.system(size: 11))

            Spacer()
                .frame(height: 10)
        }
        .frame(height: 70)
        .padding(.vertical, 10)
    }
}

struct EmptyAnimationsView: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundColor(.yellow)
                .padding(.top, 10)

            Text("No animations found")
                .font(.system(size: 12))
                .foregroundColor(.white)

            Text("Record an animation first")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.top, 1)

            Button(action: onRefresh) {
                Text("Refresh")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
                    .foregroundColor(.white)
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }
}

struct AnimationsScrollView: View {
    let animations: [CapturedAnimation]
    let selectedAnimation: CapturedAnimation?
    let onSelectAnimation: (CapturedAnimation) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(animations) { animation in
                    AnimationRowItem(
                        animation: animation,
                        isSelected: selectedAnimation?.id == animation.id,
                        onSelect: { onSelectAnimation(animation) }
                    )
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 180)
    }
}

struct AnimationRowItem: View {
    let animation: CapturedAnimation
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.5), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(animation.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white : .gray)

                    HStack(spacing: 4) {
                        Text("\(animation.frames.count)f")
                            .font(.system(size: 9))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)

                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(isSelected ? .white.opacity(0.5) : .gray.opacity(0.5))

                        Text("\(String(format: "%.1f", animation.duration))s")
                            .font(.system(size: 9))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.blue.opacity(0.25) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected ? Color.blue.opacity(0.4) : Color.gray.opacity(0.15),
                        lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
