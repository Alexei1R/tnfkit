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
};

vertex VertexOut selection_vertex(VertexIn in [[stage_in]]) {
  VertexOut out;
  // Input is already in NDC coordinates (-1 to 1)
  out.position = float4(in.position.x, in.position.y, 0.0, 1.0);
  return out;
}

fragment float4 selection_fragment(VertexOut in [[stage_in]],
                                   constant float4 &color [[buffer(0)]]) {
  return color; // Use the color provided in the buffer
}
