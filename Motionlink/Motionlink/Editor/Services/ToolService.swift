import Foundation
import SwiftUI
import tnfkit
import Combine

typealias ToolSelectionHandler = (EngineTools) -> Void

class ToolService {
    static let shared = ToolService()
    private(set) var tools: [ApplicationTool] = []
    let toolChanged = PassthroughSubject<ApplicationTool?, Never>()
    let modeChanged = PassthroughSubject<ApplicationMode, Never>()
    let layersVisibilityChanged = PassthroughSubject<Bool, Never>()
    
    private(set) var toolSelectionHandler: ToolSelectionHandler?
    
    private init() {
        registerDefaultTools()
    }
    
    func setToolSelectionHandler(_ handler: @escaping ToolSelectionHandler) {
        toolSelectionHandler = handler
    }
    
    func registerTool(_ tool: ApplicationTool) {
        tools.append(tool)
    }
    
    func selectTool(_ tool: ApplicationTool) {
        toolChanged.send(tool)
        
        if let handler = toolSelectionHandler {
            handler(tool.engineTool)
        } else {
            print("Warning: Tool selection handler not set")
        }
    }
    
    func toolsForMode(_ mode: ApplicationMode) -> [ApplicationTool] {
        return tools.filter { $0.supportedModes.contains(mode) }
    }
    
    func findTool(byName name: String) -> ApplicationTool? {
        return tools.first { $0.name == name }
    }
    
    func findEngineTool(byName name: String) -> EngineTools? {
        guard let tool = findTool(byName: name) else { return nil }
        return tool.engineTool
    }
    
    private func registerDefaultTools() {
        // Selection tools
        registerTool(
            ApplicationTool(
                name: "Select",
                icon: "scribble.variable",
                group: .selection,
                engineTool: .select,
                supportedModes: [.object]
            )
        )
        
        // Manipulation tools
        registerTool(
            ApplicationTool(
                name: "Control",
                icon: "move.3d",
                group: .manipulation,
                engineTool: .control,
                supportedModes: [.object]
            )
        )
        
        // Object mode specific tools
        registerTool(
            ApplicationTool(
                name: "Add",
                icon: "cube",
                group: .creation,
                engineTool: .add,
                supportedModes: [.object]
            )
        )
        
        
        // Record mode specific tools
        registerTool(
            ApplicationTool(
                name: "Record",
                icon: "record.circle",
                group: .creation,
                engineTool: .none,
                supportedModes: [.record]
            )
        )

    }
}
