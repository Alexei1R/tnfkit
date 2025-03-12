import Foundation
import SwiftUI
import Combine
import tnfkit

class ToolViewModel: ObservableObject {
    // Published properties
    @Published var selectedTool: ApplicationTool?
    @Published var currentMode: ApplicationMode = .object
    @Published var showLayers: Bool = false
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    private let toolService = ToolService.shared
    
    // Computed properties
    var availableTools: [ApplicationTool] {
        return toolService.toolsForMode(currentMode)
    }
    
    // Callbacks for compatibility with existing code
    private var toolSelectionCallbacks: [(ApplicationTool?) -> Void] = []
    private var layersVisibilityCallbacks: [(Bool) -> Void] = []
    private var modeChangeCallbacks: [(ApplicationMode) -> Void] = []
    
    init() {
        if let defaultTool = toolService.findTool(byName: "Control") {
            selectedTool = defaultTool
        }
        setupSubscribers()
    }
    
    // MARK: - Public Methods
    func setupToolSelectionHandler(_ handler: @escaping ToolSelectionHandler) {
        toolService.setToolSelectionHandler(handler)
        
        // Apply current tool if it exists
        if let tool = selectedTool {
            handler(tool.engineTool)
        }
    }
    
    func selectTool(_ tool: ApplicationTool) {
        selectedTool = tool
        toolService.selectTool(tool)
        notifyToolSelectionCallbacks()
    }
    
    func setMode(_ mode: ApplicationMode) {
        currentMode = mode
        
        // Ensure selected tool supports this mode
        if let selectedTool = selectedTool, !selectedTool.supportedModes.contains(mode) {
            if let firstAvailableTool = availableTools.first {
                selectTool(firstAvailableTool)
            }
        }
        
        notifyModeChangeCallbacks()
    }
    
    func toggleLayers() {
        showLayers.toggle()
        notifyLayersVisibilityCallbacks()
    }
    
    // MARK: - Callback Registration (backward compatibility)
    func onToolSelection(_ callback: @escaping (ApplicationTool?) -> Void) {
        toolSelectionCallbacks.append(callback)
        if let selectedTool = selectedTool {
            callback(selectedTool)
        }
    }
    
    func onLayersVisibilityChange(_ callback: @escaping (Bool) -> Void) {
        layersVisibilityCallbacks.append(callback)
        callback(showLayers)
    }
    
    func onModeChange(_ callback: @escaping (ApplicationMode) -> Void) {
        modeChangeCallbacks.append(callback)
        callback(currentMode)
    }
    
    // Functions to maintain API compatibility with old ToolSelector
    func removeToolSelectionCallback(_ callback: @escaping (ApplicationTool?) -> Void) {
        toolSelectionCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    func removeLayersVisibilityCallback(_ callback: @escaping (Bool) -> Void) {
        layersVisibilityCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    func removeModeChangeCallback(_ callback: @escaping (ApplicationMode) -> Void) {
        modeChangeCallbacks.removeAll(where: { $0 as AnyObject === callback as AnyObject })
    }
    
    // MARK: - Private Methods
    private func setupSubscribers() {
        $selectedTool
            .compactMap { $0 }
            .sink { [weak self] tool in
                self?.toolService.selectTool(tool)
            }
            .store(in: &cancellables)
    }
    
    private func notifyToolSelectionCallbacks() {
        toolSelectionCallbacks.forEach { $0(selectedTool) }
    }
    
    private func notifyLayersVisibilityCallbacks() {
        layersVisibilityCallbacks.forEach { $0(showLayers) }
    }
    
    private func notifyModeChangeCallbacks() {
        modeChangeCallbacks.forEach { $0(currentMode) }
    }
}

// Type alias for backward compatibility
typealias ToolSelector = ToolViewModel
typealias Tool = ApplicationTool
typealias Mode = ApplicationMode
