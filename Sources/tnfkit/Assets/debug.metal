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
                                   texture2d<uint> maskTexture [[texture(0)]],
                                   sampler textureSampler [[sampler(0)]]) {
    
    // Calculate texture coordinates in pixels
    uint2 pixelCoord = uint2(in.texCoord * float2(maskTexture.get_width(), maskTexture.get_height()));
    
    // Read the mask value (returns uint4, we need the first component)
    uint4 maskValues = maskTexture.read(pixelCoord);
    uint maskValue = maskValues.r;  // Get the first component
    
    // Visualize the mask with color
    if (maskValue > 0) {
        // Bright cyan for selected areas
        return float4(0.0, 1.0, 1.0, 1.0);
    } else {
        // Dark blue for unselected areas (with alpha for visibility)
        return float4(0.0, 0.1, 0.2, 0.3);
    }
}
