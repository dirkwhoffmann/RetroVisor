#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float zoom;
    float intensity;
    float2 resolution;
    float2 center;
    float2 mouse;
    float4 texRect;
};

//
// Vertex shader
//

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}


//
// Fragment shader
//

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              constant Uniforms& uniforms [[buffer(0)]],
                              sampler sam [[sampler(0)]]) {


    float2 uv = in.texCoord;
    float2 texOrigin = uniforms.texRect.xy;
    float2 texSize = uniforms.texRect.zw;

    // Normalize the texture coordinate:
    float2 normuv = (in.texCoord - texOrigin) / texSize;

    // --- Barrel distortion ---
    /*
     float2 center = float2(0.5, 0.5);
     float2 offset = uv - center;
     float dist = dot(offset, offset);
     uv = center + offset * (1.0 + dist * 0.1); // Adjust 0.1 to control distortion
     */

    // --- Sample texture ---
    float4 color = tex.sample(sam, uv);

    // --- Scanlines ---
    float scanline = 0.85 + 0.15 * sin(normuv.y * uniforms.resolution.y * 3.14159);
    color.rgb *= scanline;

    // --- Slight color shift (RGB offset) for chromatic aberration ---
    float2 shift = float2(1.0 / uniforms.resolution.x, 1.0 / uniforms.resolution.x);
    float r = tex.sample(sam, uv - shift).r;
    float g = tex.sample(sam, uv).g;
    float b = tex.sample(sam, uv + shift).b;
    color.rgb = float3(r, g, b) * scanline;

    return color;
}

fragment float4 fragment_ripple(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                constant Uniforms& uniforms [[buffer(0)]],
                                sampler sam [[sampler(0)]]) {

    float2 shift = float2(0.5 - 0.5 / uniforms.zoom, 0.5 - 0.5 / uniforms.zoom);
    float2 uv = in.texCoord / uniforms.zoom + shift;
    float2 mouse = uniforms.mouse / uniforms.zoom + shift;

    if (uniforms.intensity > 0.0) {

        float2 dir = uv - mouse;
        float dist = length(dir);

        // Ripple parameters
        float waveFreq = 60.0;
        float waveSpeed = 10.0;
        float waveAmp = 0.005 * uniforms.intensity;
        float brightnessDepth = 0.15 * uniforms.intensity;

        // Displace UVs outward along radial direction
        float ripple = sin((dist * waveFreq) - (uniforms.time * waveSpeed));
        float offset = ripple * waveAmp;
        float2 rippleUV = uv + (dist > 0.0001 ? normalize(dir) * offset : float2(0.0));

        // Sample the texture
        float4 color = tex.sample(sam, rippleUV);

        // Darken wave fronts (multiply color)
        float brightness = 1.0 - brightnessDepth * (cos((dist * waveFreq) - (uniforms.time * waveSpeed)) * 0.5 + 0.5);

        color.rgb *= brightness;

        return color;
    }
    return tex.sample(sam, uv);
}
