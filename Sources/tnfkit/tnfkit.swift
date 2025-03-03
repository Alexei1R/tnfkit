// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import MetalKit
import SwiftUI

@MainActor
public final class TNFEngine {
    private var device: MTLDevice?
    
    public init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        self.device = device

    }
    
    public func start(with view: MTKView) {
        print("TNFEngine started with view: \(view)")
    }
    
    public func getMetalDevice() -> MTLDevice? {
        return device
    }

    @MainActor
    public func update(view: MTKView) {
    }

    @MainActor
    public func resize(to size: CGSize) {
    }

    //NOTE: Creates and returns the appropriate ViewportView for the current platform
    public func createViewport() -> ViewportView {
        return ViewportView(engine: self)
    }
}
