// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
  float2 texCoord [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

vertex VertexOut vertex_main_debug(VertexIn in [[stage_in]]) {
  VertexOut out;
  // Position is already in NDC coordinates, no transformations needed
  out.position = float4(in.position, 1.0);
  out.texCoord = in.texCoord;
  return out;
}

fragment float4 fragment_main_debug(VertexOut in [[stage_in]],
                                    texture2d<float> debugTexture
                                    [[texture(0)]],
                                    sampler textureSampler [[sampler(0)]]) {
  return debugTexture.sample(textureSampler, in.texCoord);
}
