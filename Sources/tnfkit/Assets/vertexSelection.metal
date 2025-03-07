// Copyright (c) 2025 The Noughy Fox
// Created by: Alexei1R
// Date: 2025-03-06
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;

// Input vertex structure
struct VertexIn {
  float3 position [[attribute(0)]];
  float3 normal [[attribute(1)]];
  float2 texCoords [[attribute(2)]];
  float3 tangent [[attribute(3)]];
  float3 bitangent [[attribute(4)]];
};

// Output vertex structure with selection state
struct VertexOut {
  float4 position [[position]];
  float3 worldPosition;
  float3 normal;
  float2 texCoords;
  float3 color;
  float isSelected;
};

// Uniform data
struct Uniforms {
  float4x4 modelMatrix;
  float4x4 viewMatrix;
  float4x4 projectionMatrix;
  float3 lightPosition;
  float3 viewPosition;
};

// Vertex shader for selectable model
vertex VertexOut vertex_selection(VertexIn in [[stage_in]],
                                  constant Uniforms &uniforms [[buffer(1)]],
                                  constant uint32_t *selectionStates
                                  [[buffer(2)]],
                                  uint vertexID [[vertex_id]]) {
  VertexOut out;

  // Transform position from model to world space
  float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);

  // Transform to clip space
  out.position =
      uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;

  // Pass through world position for lighting calculations
  out.worldPosition = worldPosition.xyz;

  // Transform normals using normal matrix (inverse transpose of model matrix)
  float3x3 normalMatrix =
      float3x3(uniforms.modelMatrix[0].xyz, uniforms.modelMatrix[1].xyz,
               uniforms.modelMatrix[2].xyz);
  out.normal = normalize(normalMatrix * in.normal);

  // Pass through texture coordinates
  out.texCoords = in.texCoords;

  // Base color derived from normal
  out.color = normalize(in.normal) * 0.5 + 0.5;

  // Pass through selection state from vertex buffer to fragment shader
  out.isSelected = float(selectionStates[vertexID]);

  return out;
}

// Fragment shader for selectable model
fragment float4 fragment_selection(VertexOut in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(1)]],
                                   constant float3 &highlightColor
                                   [[buffer(3)]]) {
  // Normalize interpolated normal
  float3 normal = normalize(in.normal);

  // Calculate lighting vectors
  float3 lightDirection = normalize(uniforms.lightPosition - in.worldPosition);
  float3 viewDirection = normalize(uniforms.viewPosition - in.worldPosition);

  // Ambient lighting component
  float3 ambient = float3(0.3, 0.3, 0.3); // Increased base ambient

  // Diffuse lighting component
  float diffuseStrength = max(dot(normal, lightDirection), 0.0);
  float3 diffuse = diffuseStrength * float3(0.7, 0.7, 0.7);

  // Specular lighting component (Blinn-Phong)
  float3 halfVector = normalize(lightDirection + viewDirection);
  float specularStrength = pow(max(dot(normal, halfVector), 0.0), 32.0);
  float3 specular = specularStrength * float3(1.0, 1.0, 1.0) * 0.3;

  float3 finalColor;

  // If vertex is selected, use highlight color with stronger effect
  if (in.isSelected > 0.5) {
    // Use the highlight color directly with minimal lighting influence
    finalColor = highlightColor;

    // Add ambient and diffuse lighting but keep the orange color dominant
    finalColor = finalColor * (ambient + diffuse * 0.5);

    // Add specular highlight on top
    finalColor += specular * 0.5;
  } else {
    // Normal rendering with standard lighting
    float3 baseColor = in.color;
    finalColor = (ambient + diffuse) * baseColor + specular;
  }

  // Clamp to prevent overflow
  finalColor = clamp(finalColor, 0.0, 1.0);

  return float4(finalColor, 1.0);
}
