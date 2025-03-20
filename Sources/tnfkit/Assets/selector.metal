// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

#include <metal_stdlib>
using namespace metal;

//NOTE: Vertex input data
struct VertexIn {
  float2 position [[attribute(0)]];
};

//NOTE: Data passed to fragment shader
struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

//NOTE: Vertex shader for selection rendering
vertex VertexOut vertex_main_selector(VertexIn in [[stage_in]], 
                                     constant float &param [[buffer(1)]]) {
  VertexOut out;
  
  //NOTE: Use Z=0 to ensure drawing on top
  out.position = float4(in.position, 0.0, 1.0);
  
  //NOTE: Transform to [0,1] space for gradient effects
  out.uv = in.position.xy * 0.5 + 0.5;
  
  return out;
}

//NOTE: Fragment shader for selection rendering
fragment float4 fragment_main_selector(VertexOut in [[stage_in]], 
                                      constant float4 &color [[buffer(0)]]) {
  //NOTE: Selection fill and outline use different shading
  if (color.a < 0.3) {
    //NOTE: Fill area with gradient
    float distFromCenter = length(in.uv - float2(0.5));
    float gradientFactor = 1.0 - distFromCenter * 0.5;
    return float4(color.rgb, color.a * gradientFactor);
  } else {
    //NOTE: Solid outline
    return float4(color.rgb, 1.0);
  }
}

//NOTE: Vertex shader for selection mask rendering
vertex VertexOut vertex_main_selector_mask(VertexIn in [[stage_in]]) {
  VertexOut out;
  
  //NOTE: Use Z=0 to ensure drawing on top
  out.position = float4(in.position, 0.0, 1.0);
  
  //NOTE: Pass through UV coordinates
  out.uv = in.position.xy * 0.5 + 0.5;
  
  return out;
}

//NOTE: Fragment shader for selection mask rendering (outputs 1 or 0)
fragment uint fragment_main_selector_mask(VertexOut in [[stage_in]]) {
  //NOTE: Output 1 for every fragment inside the selection shape
  return 1;
}