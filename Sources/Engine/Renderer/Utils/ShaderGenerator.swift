// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import Metal
import MetalKit

public class ShaderGenerator {
    private let bufferStack: BufferStack
    private let pipelineConfig: PipelineConfig

    public init(bufferStack: BufferStack, pipelineConfig: PipelineConfig) {
        self.bufferStack = bufferStack
        self.pipelineConfig = pipelineConfig
    }

    public func generateShader(fixedColor: SIMD4<Float> = SIMD4<Float>(1.0, 0.0, 0.0, 1.0))
        -> String
    {
        var code = """

            // Copyright (c) 2025 The Noughy Fox
            //
            // This software is released under the MIT License.
            // https://opensource.org/licenses/MIT

            #include <metal_stdlib>
            using namespace metal;

            """

        // Generate vertex input struct based on buffer layouts
        code += generateVertexInputStruct()

        // Generate vertex output struct
        code += generateVertexOutputStruct()

        // Generate uniform struct
        code += generateUniformStruct()

        // Vertex function
        code += generateVertexFunction()

        // Fragment function with fixed color
        code += generateFragmentFunction(fixedColor: fixedColor)

        return code
    }

    private func generateVertexInputStruct() -> String {
        var structCode = """
            struct VertexIn {
            """

        // Find the vertex buffer layout
        for (layout, bufferIndex) in pipelineConfig.bufferLayouts
        where bufferIndex == BufferType.vertex.defaultBindingIndex {
            for (i, element) in layout.elements.enumerated() {
                let metalType = elementTypeToMetalType(element.type)
                // Use lowercase names for Metal shader attributes
                let attributeName = element.name.lowercased()
                structCode += "\n    \(metalType) \(attributeName) [[attribute(\(i))]];"
            }
        }

        structCode += "\n};\n"
        return structCode
    }

    private func generateVertexOutputStruct() -> String {
        return """

            struct VertexOut {
                float4 position [[position]];
                float4 color;
            };
            """
    }

    private func generateUniformStruct() -> String {
        var uniformLayouts = pipelineConfig.bufferLayouts.filter { layout, bufferIndex in
            bufferIndex == BufferType.uniform.defaultBindingIndex
        }

        var structCode = """

            struct Uniforms {
            """

        if uniformLayouts.isEmpty {
            structCode += """

                // Define your uniform structure here manually
                // Example:
                  float4x4 modelMatrix;
                  float4x4 viewMatrix;
                  float4x4 projectionMatrix;
                  float3 lightPosition;
                  float3 viewPosition;
                """
        } else {
            for (layout, _) in uniformLayouts {
                for element in layout.elements {
                    let metalType = elementTypeToMetalType(element.type)
                    let uniformName = element.name.lowercased()
                    structCode += "\n    \(metalType) \(uniformName);"
                }
            }
        }

        structCode += "\n};\n"
        return structCode
    }

    private func generateVertexFunction() -> String {
        var vertexFunc = """

            vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(1)]]) {
                VertexOut out;
                out.position = float4(in.position, 1.0);
                
                // Pass through color if available, otherwise use a default
            """

        // Check if we have a color attribute in the vertex input
        let hasColor = pipelineConfig.bufferLayouts.contains { layout, _ in
            layout.elements.contains { $0.name.lowercased() == "color" }
        }

        if hasColor {
            vertexFunc += """

                out.color = in.color;
                """
        } else {
            vertexFunc += """

                // Default color if vertex color not provided
                out.color = float4(1.0, 1.0, 1.0, 1.0);
                """
        }

        vertexFunc += """
                
                return out;
            }
            """

        return vertexFunc
    }

    private func generateFragmentFunction(fixedColor: SIMD4<Float>) -> String {
        return """

            fragment float4 fragment_main(VertexOut in [[stage_in]]) {
                // Use fixed color for rendering
                return float4(\(fixedColor.x), \(fixedColor.y), \(fixedColor.z), \(fixedColor.w));
            }
            """
    }

    private func hasUniformBuffers() -> Bool {
        // Always return true to generate the uniform structure placeholder
        return true
    }

    private func elementTypeToMetalType(_ type: BufferDataType) -> String {
        switch type {
        case .float: return "float"
        case .float2: return "float2"
        case .float3: return "float3"
        case .float4: return "float4"
        case .int: return "int"
        case .int2: return "int2"
        case .int3: return "int3"
        case .int4: return "int4"
        case .uint16: return "ushort"
        case .uint16x2: return "ushort2"
        case .uint16x4: return "ushort4"
        case .bool: return "bool"
        }
    }

    public func compileShader(device: MTLDevice) throws -> MTLLibrary {
        let shaderSource = generateShader()

        var library: MTLLibrary?
        var error: Error?

        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch let capturedError {
            error = capturedError
            print("Failed to compile shader: \(capturedError.localizedDescription)")
            print("Shader source:\n\(shaderSource)")
        }

        guard let metalLibrary = library else {
            throw error ?? ShaderError.libraryCreationFailed
        }

        return metalLibrary
    }
}

