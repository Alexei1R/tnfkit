import Foundation
import SwiftUI

enum Mode: String, CaseIterable, Identifiable {
    case object = "Obj"
    case vertex = "Vertex"
    case animate = "Animate"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .object:
            return "cube.fill"
        case .vertex:
            return "circle.grid.3x3.fill"
        case .animate:
            return "figure.wave"
        }
    }
}

class ModeSelector: ObservableObject {
    typealias ModeSelectionCallback = (Mode) -> Void
    private var modeSelectionCallbacks: [ModeSelectionCallback] = []

    typealias ModeClickCallback = (Mode) -> Void
    private var modeClickCallbacks: [ModeClickCallback] = []
    
    @Published var selectedMode: Mode = .object {
        didSet {
            notifyModeSelectionCallbacks()
        }
    }
    
    func onModeSelection(_ callback: @escaping ModeSelectionCallback) {
        modeSelectionCallbacks.append(callback)
        callback(selectedMode)
    }
    
    func removeModeSelectionCallback(_ callback: @escaping ModeSelectionCallback) {
        modeSelectionCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    private func notifyModeSelectionCallbacks() {
        modeSelectionCallbacks.forEach { callback in
            callback(selectedMode)
        }
    }



    func onModeClick(_ callback: @escaping ModeClickCallback) {
        modeClickCallbacks.append(callback)
        callback(selectedMode)
    }

    func removeModeClickCallback(_ callback: @escaping ModeClickCallback) {
        modeClickCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }


}
