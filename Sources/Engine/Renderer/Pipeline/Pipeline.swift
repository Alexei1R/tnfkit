// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import MetalKit

public enum BlendMode {
    case opaque, transparent, additive
    public var descriptor: MTLRenderPipelineColorAttachmentDescriptor {
        let descriptor = MTLRenderPipelineColorAttachmentDescriptor()
        switch self {
        case .opaque:
            descriptor.isBlendingEnabled = false
        case .transparent:
            descriptor.isBlendingEnabled = true
            descriptor.rgbBlendOperation = .add
            descriptor.alphaBlendOperation = .add
            descriptor.sourceRGBBlendFactor = .sourceAlpha
            descriptor.sourceAlphaBlendFactor = .sourceAlpha
            descriptor.destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        case .additive:
            descriptor.isBlendingEnabled = true
            descriptor.rgbBlendOperation = .add
            descriptor.alphaBlendOperation = .add
            descriptor.sourceRGBBlendFactor = .sourceAlpha
            descriptor.sourceAlphaBlendFactor = .one
            descriptor.destinationRGBBlendFactor = .one
            descriptor.destinationAlphaBlendFactor = .one
        }
        return descriptor
    }
}

public struct PipelineConfig {
    public var name: String
    public var shaderLayout: ShaderLayout!
    public var bufferLayouts: [(BufferLayout, Int)] = []
    public var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    public var depthPixelFormat: MTLPixelFormat = .depth32Float
    public var blendMode: BlendMode = .opaque
    public var depthWriteEnabled: Bool = true
    public var depthCompareFunction: MTLCompareFunction = .less
    public init(name: String) { self.name = name }
}

public class Pipeline {

    public let config: PipelineConfig

    public let state: MTLRenderPipelineState
    public let depthState: MTLDepthStencilState?

    private var library: MTLLibrary!
    private let device: MTLDevice

    public init?(device: MTLDevice, config: PipelineConfig) {
        self.device = device
        self.config = config
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = config.name

        do {

            //NOTE: Shaders

            let library = ShaderLibrary.shared.shaderLibrary
            for element in config.shaderLayout.elements {
                guard let function = library.makeFunction(name: element.name) else {
                    Log.error("Failed to find shader function: \(element.name)")
                    return nil
                }

                switch element.type {
                case .vertex:
                    descriptor.vertexFunction = function
                case .fragment:
                    descriptor.fragmentFunction = function
                case .compute:
                    Log.warning(
                        "Compute function '\(element.name)' provided to render pipeline")
                }
            }

            if descriptor.vertexFunction == nil {
                Log.error("No vertex function provided in shader layout")
                return nil
            }

            if descriptor.fragmentFunction == nil {
                Log.warning("No fragment function provided in shader layout")
            }

            // NOTE: Vertex Layout
            if !config.bufferLayouts.isEmpty {
                let vertexDescriptor = MTLVertexDescriptor()
                for (layout, bufferIndex) in config.bufferLayouts {
                    let layoutDescriptor = layout.metalVertexDescriptor(bufferIndex: bufferIndex)
                    for i in 0..<31 where layoutDescriptor.attributes[i].format != .invalid {
                        vertexDescriptor.attributes[i] = layoutDescriptor.attributes[i]
                    }
                    vertexDescriptor.layouts[bufferIndex] = layoutDescriptor.layouts[bufferIndex]
                }
                descriptor.vertexDescriptor = vertexDescriptor
            }

            //NOTE: Texture formats
            let colorAttachment = config.blendMode.descriptor
            colorAttachment.pixelFormat = config.colorPixelFormat
            descriptor.colorAttachments[0] = colorAttachment
            descriptor.depthAttachmentPixelFormat = config.depthPixelFormat
            self.state = try device.makeRenderPipelineState(descriptor: descriptor)
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = config.depthCompareFunction
            depthDescriptor.isDepthWriteEnabled = config.depthWriteEnabled
            self.depthState = device.makeDepthStencilState(descriptor: depthDescriptor)

        } catch {
            Log.error("Failed to create pipeline: \(error.localizedDescription)")
            return nil
        }

    }

    public func bind(to encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(state)
        if let ds = depthState { encoder.setDepthStencilState(ds) }
    }

}
