// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
  float4 color [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
};

vertex VertexOut grid_vertex(VertexIn in [[stage_in]],
                             constant float4x4 &modelMatrix [[buffer(1)]],
                             constant float4x4 &viewMatrix [[buffer(2)]],
                             constant float4x4 &projectionMatrix
                             [[buffer(3)]]) {
  VertexOut out;

  float4 worldPosition = modelMatrix * float4(in.position, 1.0);
  float4 viewPosition = viewMatrix * worldPosition;
  out.position = projectionMatrix * viewPosition;

  out.color = in.color;

  return out;
}

fragment float4 grid_fragment(VertexOut in [[stage_in]]) { return in.color; }
