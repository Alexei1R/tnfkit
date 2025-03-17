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
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoord;
    float3 tangent;
    float3 bitangent;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 lightPosition;
    float3 viewPosition;
};

vertex VertexOut vertex_main_model(VertexIn in [[stage_in]],
                           constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    // Calculate position
    float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz / worldPos.w;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    
    // Transform normals and tangents to world space
    float3x3 normalMatrix = float3x3(
        uniforms.modelMatrix[0].xyz,
        uniforms.modelMatrix[1].xyz,
        uniforms.modelMatrix[2].xyz
    );
    
    out.normal = normalize(normalMatrix * in.normal);
    out.tangent = normalize(normalMatrix * in.tangent);
    out.bitangent = normalize(normalMatrix * in.bitangent);
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 fragment_main_model(VertexOut in [[stage_in]],
                            texture2d<float> albedoTexture [[texture(0)]],
                            sampler textureSampler [[sampler(0)]]) {
    // Use the provided sampler instead of creating a new one
    // This ensures we use the sampler created in the Texture class
    
    // Simple implementation for now (Blinn-Phong)
    float3 albedo = albedoTexture.sample(textureSampler, in.texCoord).rgb;
    
    // Normalize interpolated vectors
    float3 N = normalize(in.normal);
    float3 L = normalize(float3(0, 5, 0) - in.worldPosition);
    float3 V = normalize(float3(0, 0, 5) - in.worldPosition);
    float3 H = normalize(L + V);
    
    // Basic diffuse lighting
    float diffuse = max(dot(N, L), 0.0);
    
    // Basic specular (Blinn-Phong)
    float specular = pow(max(dot(N, H), 0.0), 64.0) * 0.5;
    
    // Ambient term
    float3 ambient = albedo * 0.3;
    
    // Final color
    float3 finalColor = ambient + (albedo * diffuse) + specular;
    
    return float4(finalColor, 1.0);
}