import SwiftUI
import ARKit
import RealityKit
import Combine

struct ARBodyTrackingView: UIViewRepresentable {
    var onBodyTracking: ((ARBodyAnchor) -> Void)?
    var onFrame: ((ARFrame) -> Void)?
    var characterName: String = "robot" // Default character model
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        guard ARBodyTrackingConfiguration.isSupported else {
            print("Body tracking is not supported on this device")
            return arView
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
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
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
