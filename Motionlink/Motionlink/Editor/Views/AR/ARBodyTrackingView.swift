// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import SwiftUI
import ARKit
import RealityKit
import Combine

struct ARBodyTrackingView: UIViewRepresentable {
    var onBodyTracking: ((ARBodyAnchor) -> Void)?
    var onFrame: ((ARFrame) -> Void)?
    var characterName: String = "robot" // Default character model
    
    func makeUIView(context: Context) -> ARViewContainer {
        let arViewContainer = ARViewContainer(frame: .zero)
        let arView = arViewContainer.arView
        
        guard ARBodyTrackingConfiguration.isSupported else {
            print("Body tracking is not supported on this device")
            return arViewContainer
        }
        
        // Create body tracking configuration
        let configuration = ARBodyTrackingConfiguration()
        configuration.frameSemantics.insert(.bodyDetection)
        
        // Set up session delegate
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        
        // Setup character and anchors
        context.coordinator.setupCharacter(in: arView, characterName: characterName)
        
        // Run the session
        arView.session.run(configuration)
        
        return arViewContainer
    }
    
    func updateUIView(_ uiView: ARViewContainer, context: Context) {
        context.coordinator.onBodyTracking = onBodyTracking
        context.coordinator.onFrame = onFrame
        context.coordinator.characterName = characterName
        
        // If character name changed, reload the character
        if context.coordinator.characterName != characterName {
            context.coordinator.characterName = characterName
            if let arView = context.coordinator.arView {
                context.coordinator.setupCharacter(in: arView, characterName: characterName)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBodyTracking: onBodyTracking, onFrame: onFrame)
    }
    
    // Custom ARView container to handle aspect ratio
    class ARViewContainer: UIView {
        let arView: ARView
        
        override init(frame: CGRect) {
            self.arView = ARView(frame: .zero)
            super.init(frame: frame)
            
            // Add ARView as a subview
            addSubview(arView)
            
            // Configure AR view appearance
            arView.translatesAutoresizingMaskIntoConstraints = false
            
            // Apply black background to container
            backgroundColor = .black
            
            // Setup constraints to center AR view while maintaining aspect ratio
            NSLayoutConstraint.activate([
                // Center AR view
                arView.centerXAnchor.constraint(equalTo: centerXAnchor),
                arView.centerYAnchor.constraint(equalTo: centerYAnchor),
                
                // Constrain width and height while maintaining aspect ratio
                arView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
                arView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor),
                
                // Aspect ratio constraint will be added dynamically when the camera feed begins
            ])
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            updateARViewLayout()
        }
        
        // Adjust the AR view layout to respect aspect ratio
        private func updateARViewLayout() {
            // Default aspect ratio (4:3) if we haven't determined from camera yet
            var aspectRatio: CGFloat = 4.0/3.0
            
            // Get actual camera aspect ratio if available
            if let camera = arView.session.currentFrame?.camera {
                let resolution = camera.imageResolution
                aspectRatio = CGFloat(resolution.width) / CGFloat(resolution.height)
            }
            
            let containerSize = bounds.size
            let containerAspect = containerSize.width / containerSize.height
            
            // Calculate dimensions to fit camera feed while preserving aspect ratio
            if aspectRatio > containerAspect {
                // Camera is wider than container - fit to width with black bars on top/bottom
                let newHeight = containerSize.width / aspectRatio
                arView.frame = CGRect(
                    x: 0,
                    y: (containerSize.height - newHeight) / 2,
                    width: containerSize.width,
                    height: newHeight
                )
            } else {
                // Camera is taller than container - fit to height with black bars on sides
                let newWidth = containerSize.height * aspectRatio
                arView.frame = CGRect(
                    x: (containerSize.width - newWidth) / 2,
                    y: 0,
                    width: newWidth,
                    height: containerSize.height
                )
            }
        }
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var arView: ARView?
        var onBodyTracking: ((ARBodyAnchor) -> Void)?
        var onFrame: ((ARFrame) -> Void)?
        var characterName: String = "robot"
        
        // Character visualization properties
        var character: BodyTrackedEntity?
        let characterAnchor = AnchorEntity()
        var cancellable: AnyCancellable?
        
        init(onBodyTracking: ((ARBodyAnchor) -> Void)? = nil,
             onFrame: ((ARFrame) -> Void)? = nil) {
            self.onBodyTracking = onBodyTracking
            self.onFrame = onFrame
            super.init()
        }
        
        func setupCharacter(in arView: ARView, characterName: String) {
            // Remove existing character if present
            if let existingCharacter = character {
                existingCharacter.removeFromParent()
                character = nil
            }
            
            // Add anchor to scene if not already added
            if characterAnchor.parent == nil {
                arView.scene.addAnchor(characterAnchor)
            }
            
            // Load the character model
            print("Loading character model: \(characterName)")
            cancellable = Entity.loadBodyTrackedAsync(named: characterName).sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("Error: Unable to load model: \(error.localizedDescription)")
                    }
                    self.cancellable?.cancel()
                },
                receiveValue: { [weak self] (character: Entity) in
                    guard let self = self else { return }
                    
                    if let character = character as? BodyTrackedEntity {
                        // Set exact 1:1 scale to ensure correct alignment
                        character.scale = [1.0, 1.0, 1.0]
                        
                        // Store reference to character
                        self.character = character
                        
                        // Immediately add character to anchor for proper alignment
                        self.characterAnchor.addChild(character)
                        
                        print("Character model '\(characterName)' loaded successfully")
                    } else {
                        print("Error: Unable to load model as BodyTrackedEntity")
                    }
                    self.cancellable?.cancel()
                }
            )
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
                
                // Update character position to perfectly match body position
                // Without adding any translation - exact 1:1 mapping
                let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
                characterAnchor.position = bodyPosition
                characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
                
                // Call the body tracking callback to process the data
                DispatchQueue.main.async {
                    self.onBodyTracking?(bodyAnchor)
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Process frame data
            DispatchQueue.main.async {
                self.onFrame?(frame)
                
                // If this is our parent view container, update the layout
                if let arView = self.arView, let container = arView.superview as? ARViewContainer {
                    container.setNeedsLayout()
                }
            }
        }
        
        // Handle session interruptions to ensure tracking resumes properly
        func sessionWasInterrupted(_ session: ARSession) {
            print("AR session was interrupted")
        }
        
        func sessionInterruptionEnded(_ session: ARSession) {
            print("AR session interruption ended")
            
            // Reset tracking if needed
            if let arView = arView {
                let configuration = ARBodyTrackingConfiguration()
                configuration.frameSemantics.insert(.bodyDetection)
                arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            }
        }
    }
}
