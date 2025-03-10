// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;
struct VertexIn {
  float3 position [[attribute(0)]];
  float3 color [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
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
  out.position = float4(in.position, 1.0);

  return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
  return float4(1.0, 0.0, 0.0, 1.0);
}
