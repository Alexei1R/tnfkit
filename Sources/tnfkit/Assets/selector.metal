// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;
struct VertexIn {
  float2 position [[attribute(0)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
};

vertex VertexOut vertex_main_selector(VertexIn in [[stage_in]]) {
  VertexOut out;
  out.position = float4(in.position, 1.0);
  out.color = float4(1.0, 1.0, 1.0, 1.0);
  return out;
}
fragment float4 fragment_main_selector(VertexOut in [[stage_in]]) {
  // Use fixed color for rendering
  return float4(1.0, 0.0, 0.0, 1.0);
}
