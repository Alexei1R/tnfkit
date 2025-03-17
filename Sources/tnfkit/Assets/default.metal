// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
  float4 color [[attribute(1)]];
  float2 texCoord [[attribute(2)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
  float2 texCoord;
};

struct Uniforms {
  float4x4 modelMatrix;
  float4x4 viewMatrix;
  float4x4 projectionMatrix;
  float3 lightPosition;
  float3 viewPosition;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]]) {
  VertexOut out;

  // Apply model-view-projection transformation
  float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
  float4 viewPosition = uniforms.viewMatrix * worldPosition;
  out.position = uniforms.projectionMatrix * viewPosition;

  out.color = in.color;
  out.texCoord = in.texCoord;
  return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> colorTexture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
  float4 textureColor = colorTexture.sample(textureSampler, in.texCoord);
  return textureColor * in.color;
}
