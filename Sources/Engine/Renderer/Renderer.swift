// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import MetalKit

public class Renderer {
    public init(view: MTKView) {

    }

    deinit {

    }

    public func beginFrame(camera: Camera) {

    }

    //Interface for drawing
    public func drawGeometry<GeometryVertex>(geometry: [GeometryVertex]) {
        // Draw geometry
    }

    public func resize(size: vec2i) {}
    public func endFrame() {}

}
