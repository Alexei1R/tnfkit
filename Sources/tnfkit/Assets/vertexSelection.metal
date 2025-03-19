// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
  float3 normal [[attribute(1)]];
  float2 texCoords [[attribute(2)]];
  float3 tangent [[attribute(3)]];
  float3 bitangent [[attribute(4)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 worldPosition;
  float3 normal;
  float2 texCoords;
  float3 color;
  float isSelected;
  int jointIndex;
};

struct Uniforms {
  float4x4 modelMatrix;
  float4x4 viewMatrix;
  float4x4 projectionMatrix;
  float3 lightPosition;
  float3 viewPosition;
};

vertex VertexOut vertex_selection(VertexIn in [[stage_in]],
                                  constant Uniforms &uniforms [[buffer(1)]],
                                  constant uint32_t *selectionStates [[buffer(2)]],
                                  uint vertexID [[vertex_id]],
                                  constant int32_t *jointIndices [[buffer(4)]]) {
  VertexOut out;

  float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);

  out.position =
      uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;

  out.worldPosition = worldPosition.xyz;

  float3x3 normalMatrix =
      float3x3(uniforms.modelMatrix[0].xyz, uniforms.modelMatrix[1].xyz,
               uniforms.modelMatrix[2].xyz);
  out.normal = normalize(normalMatrix * in.normal);

  out.texCoords = in.texCoords;

  out.color = normalize(in.normal) * 0.5 + 0.5;

  out.isSelected = float(selectionStates[vertexID]);
  
  // Add joint index to output (-1 means no joint assigned)
  out.jointIndex = jointIndices[vertexID];

  return out;
}

fragment float4 fragment_selection(VertexOut in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(1)]],
                                   constant float3 &highlightColor [[buffer(3)]],
                                   constant float3 *jointColors [[buffer(5)]],
                                   constant int &jointColorCount [[buffer(6)]]) {
  float3 normal = normalize(in.normal);

  float3 lightDirection = normalize(uniforms.lightPosition - in.worldPosition);
  float3 viewDirection = normalize(uniforms.viewPosition - in.worldPosition);

  float3 ambient = float3(0.3, 0.3, 0.3); // Increased base ambient

  float diffuseStrength = max(dot(normal, lightDirection), 0.0);
  float3 diffuse = diffuseStrength * float3(0.7, 0.7, 0.7);

  // Specular lighting component (Blinn-Phong)
  float3 halfVector = normalize(lightDirection + viewDirection);
  float specularStrength = pow(max(dot(normal, halfVector), 0.0), 32.0);
  float3 specular = specularStrength * float3(1.0, 1.0, 1.0) * 0.3;

  float3 finalColor;

  // First priority: show selection highlight
  if (in.isSelected > 0.5) {
    finalColor = highlightColor;
    finalColor = finalColor * (ambient + diffuse * 0.5);
    finalColor += specular * 0.5;
  } 
  // Second priority: show joint assignment color
  else if (in.jointIndex >= 0 && in.jointIndex < jointColorCount) {
    // Get color from joint color array
    float3 jointColor = jointColors[in.jointIndex];
    
    // Apply lighting but preserve vivid joint colors
    finalColor = jointColor * (ambient + diffuse * 0.7);
    finalColor += specular * 0.6;
  } 
  // Default: regular material color
  else {
    float3 baseColor = in.color;
    finalColor = (ambient + diffuse) * baseColor + specular;
  }

  finalColor = clamp(finalColor, 0.0, 1.0);

  return float4(finalColor, 1.0);
}

kernel void compute_selection() {}
