// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import MetalKit
import SwiftUI

#if os(iOS)
    import UIKit

    @MainActor
    public struct ViewportView: UIViewRepresentable {
        private let engine: TNFEngine

        public init(engine: TNFEngine) {
            self.engine = engine
        }

        public func makeUIView(context: Context) -> MTKView {
            let view = MTKView()
            view.device = engine.getMetalDevice()
            view.delegate = context.coordinator
            view.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)
            view.enableSetNeedsDisplay = true

            //NOTE: Initialize the engine with the newly created view
            engine.start(with: view)

            return view
        }

        public func updateUIView(_ uiView: MTKView, context: Context) {}

        public func makeCoordinator() -> ViewportCoordinator {
            return ViewportCoordinator(engine: engine)
        }
    }

#elseif os(macOS)
    import AppKit

    @MainActor
    public struct ViewportView: NSViewRepresentable {
        private let engine: TNFEngine

        public init(engine: TNFEngine) {
            self.engine = engine
        }

        public func makeNSView(context: Context) -> MTKView {
            let view = MTKView()
            view.device = engine.getMetalDevice()
            view.delegate = context.coordinator
            view.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)
            view.enableSetNeedsDisplay = true

            //NOTE: Initialize the engine with the newly created view
            engine.start(with: view)

            return view
        }

        public func updateNSView(_ nsView: MTKView, context: Context) {}

        public func makeCoordinator() -> ViewportCoordinator {
            return ViewportCoordinator(engine: engine)
        }
    }
#endif

public class ViewportCoordinator: NSObject, MTKViewDelegate {
    private let engine: TNFEngine

    public init(engine: TNFEngine) {
        self.engine = engine
    }

    @MainActor
    public func draw(in view: MTKView) {
        engine.update(view: view)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        Task { @MainActor in
            engine.resize(to: size)
        }
    }
}
