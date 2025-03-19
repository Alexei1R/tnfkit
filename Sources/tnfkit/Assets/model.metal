// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
  float3 normal [[attribute(1)]];
  float2 texCoord [[attribute(2)]];
  float3 tangent [[attribute(3)]];
  float3 bitangent [[attribute(4)]];
  int4 jointIndices [[attribute(5)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 worldPosition;
  float3 normal;
  float2 texCoord;
  float3 tangent;
  float3 bitangent;
  int jointIndex; // Pass joint index to fragment shader
};

struct Uniforms {
  float4x4 modelMatrix;
  float4x4 viewMatrix;
  float4x4 projectionMatrix;
  float3 lightPosition;
  float3 viewPosition;
};

// Color lookup table for joint indices
constant float4 colorTable[10] = {
    float4(1.0, 0.0, 0.0, 1.0), // Red
    float4(0.0, 1.0, 0.0, 1.0), // Green
    float4(0.0, 0.0, 1.0, 1.0), // Blue
    float4(1.0, 1.0, 0.0, 1.0), // Yellow
    float4(1.0, 0.0, 1.0, 1.0), // Magenta
    float4(0.0, 1.0, 1.0, 1.0), // Cyan
    float4(0.5, 0.0, 0.0, 1.0), // Dark Red
    float4(0.0, 0.5, 0.0, 1.0), // Dark Green
    float4(0.0, 0.0, 0.5, 1.0), // Dark Blue
    float4(0.5, 0.5, 0.5, 1.0)  // Grey
};

vertex VertexOut vertex_main_model(VertexIn in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(1)]]) {
  VertexOut out;

  float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
  out.worldPosition = worldPos.xyz / worldPos.w;
  out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;

  float3x3 normalMatrix =
      float3x3(uniforms.modelMatrix[0].xyz, uniforms.modelMatrix[1].xyz,
               uniforms.modelMatrix[2].xyz);

  out.normal = normalize(normalMatrix * in.normal);
  out.tangent = normalize(normalMatrix * in.tangent);
  out.bitangent = normalize(normalMatrix * in.bitangent);
  out.texCoord = in.texCoord;

  // Pass the first joint index to the fragment shader
  out.jointIndex = in.jointIndices.x;

  return out;
}

fragment float4 fragment_main_model(VertexOut in [[stage_in]],
                                    texture2d<float> albedoTexture
                                    [[texture(0)]],
                                    sampler textureSampler [[sampler(0)]]) {
  float3 albedo = albedoTexture.sample(textureSampler, in.texCoord).rgb;

  float3 N = normalize(in.normal);
  float3 L = normalize(float3(0, 5, 0) - in.worldPosition);
  float3 V = normalize(float3(0, 0, 5) - in.worldPosition);
  float3 H = normalize(L + V);

  float diffuse = max(dot(N, L), 0.0);
  float specular = pow(max(dot(N, H), 0.0), 64.0) * 0.5;
  float3 ambient = albedo * 0.3;

  // Calculate base color
  float3 finalColor = ambient + (albedo * diffuse) + specular;

  // Get color from lookup table based on joint index
  // Use modulo to handle indices beyond the table size (e.g., 11 maps to 1)
  int tableIndex = (in.jointIndex - 1) % 10;
  if (tableIndex < 0)
    tableIndex = 0; // Default to first color if index is negative

  // Blend the color from the lookup table with the calculated color
  float3 selectionColor = colorTable[tableIndex].rgb;
  float3 blendedColor = mix(finalColor, selectionColor, 0.5); // 50% blend

  return float4(blendedColor, 1.0);
}
