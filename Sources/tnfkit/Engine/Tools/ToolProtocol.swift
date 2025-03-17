// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import MetalKit

@MainActor public protocol ToolInterfaceProtocol {
    func onSelected()
    func onDeselected()
    func onUpdate()

    var isActive: Bool { get set }
}

@MainActor extension ToolInterfaceProtocol {
    public mutating func onSelected() {
        isActive = true
        print("\(type(of: self)) selected")
    }

    public mutating func onDeselected() {
        isActive = false
        print("\(type(of: self)) deselected")
    }
}
