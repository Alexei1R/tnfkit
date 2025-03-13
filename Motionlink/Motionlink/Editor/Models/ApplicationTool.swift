// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import SwiftUI
import tnfkit

struct ApplicationTool: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let group: ToolGroup
    let supportedModes: [ApplicationMode]
    let engineTool: EngineTools
    
    init(name: String, icon: String, group: ToolGroup, engineTool: EngineTools, supportedModes: [ApplicationMode] = ApplicationMode.allCases) {
        self.name = name
        self.icon = icon
        self.group = group
        self.engineTool = engineTool
        self.supportedModes = supportedModes
    }
}

enum ToolGroup {
    case selection, manipulation, creation
}
