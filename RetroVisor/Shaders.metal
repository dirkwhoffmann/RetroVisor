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

// Ripple

/*
 fragment float4 fragment_main(float2 texCoord [[stage_in]],
 texture2d<float> texture [[texture(0)]],
 sampler textureSampler [[sampler(0)]],
 constant float &time [[buffer(0)]]) {
 float2 uv = texCoord;
 uv.y += 0.02 * sin(10.0 * uv.x + time * 2.0);
 uv.x += 0.02 * sin(10.0 * uv.y + time * 2.0);
 return texture.sample(textureSampler, uv);
 }
 */
/*
 fragment float4 fragment_main(float2 texCoord [[stage_in]],
 constant float &time [[buffer(0)]]) {
 float2 uv = texCoord * 2.0 - 1.0;
 float angle = atan2(uv.y, uv.x);
 float radius = length(uv);

 float shade = sin(10.0 * angle + time * 3.0) + cos(10.0 / radius - time * 2.0);
 float value = (shade + 2.0) / 4.0;

 return float4(value, value * 0.6, 1.0 - value, 1.0);
 }
 */
/*
 fragment float4 fragment_ripple(VertexOut in [[stage_in]],
 texture2d<float> texture [[texture(0)]],
 sampler textureSampler [[sampler(0)]],
 constant float &time [[buffer(0)]],
 constant float2 &center [[buffer(1)]]) {
 float2 uv = in.texCoord;

 float dist = distance(uv, center);
 float ripple = 0.03 * sin(30.0 * (dist - time * 2.0));

 float2 direction = normalize(uv - center);
 uv += ripple * direction;

 return texture.sample(textureSampler, uv);
 }
 */

float3 lavaColorMap(float t) {
    // Map a grayscale value to lava colors
    return mix(
               mix(float3(0.2, 0.0, 0.0), float3(1.0, 0.4, 0.0), smoothstep(0.2, 0.6, t)), // dark to orange
               float3(1.0, 1.0, 0.0),                                                     // to yellow
               smoothstep(0.6, 1.0, t)
               );
}



fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              constant Uniforms& uniforms [[buffer(0)]],
                              sampler sam [[sampler(0)]]) {


    // Apply a subtle offset opposite to drag direction
    float2 uv = in.texCoord;

    if (uniforms.intensity < 0.0) {

        float2 dir = uv - uniforms.mouse;
        float dist = length(dir);

        // Ripple parameters
        float waveFreq = 60.0;      // More ripples
        float waveSpeed = 10.0;
        float waveAmp = 0.005 * uniforms.intensity;      // Stronger distortion
        float brightnessDepth = 0.15 * uniforms.intensity;

        // Displace UVs outward along radial direction
        float ripple = sin((dist * waveFreq) - (uniforms.time * waveSpeed));
        float offset = ripple * waveAmp;
        float2 rippleUV = uv + (dist > 0.0001 ? normalize(dir) * offset : float2(0.0));

        // Sample the texture
        float4 color = tex.sample(sam, rippleUV);

        // Darken wave fronts (multiply color)
        // float brightness = 1.0 - brightnessDepth * (cos((dist * waveFreq) - (uniforms.time * waveSpeed)) * 0.5 + 0.5);
        float brightness = 1.0 - brightnessDepth * (cos((dist * waveFreq) - (uniforms.time * waveSpeed)) * 0.5 + 0.5);

        color.rgb *= brightness;

        return color;

        /*
         float2 uvMin = uniforms.texRect.xy;
         float2 uvMax = uniforms.texRect.zw;
         float2 localUV = (uv - uvMin) / (uvMax - uvMin);

         float2 dir = localUV - uniforms.center;
         float dist = length(dir);
         float ripple = uniforms.intensity * 0.015 * sin(30.0 * dist - uniforms.time * 10.0);
         localUV += normalize(dir) * ripple;

         uv = mix(uvMin, uvMax, localUV);
         */
    }

    {
        // float2 uv = in.texCoord;

        float2 texOrigin = uniforms.texRect.xy;
        float2 texSize = uniforms.texRect.zw;

        // Normalize the texture coordinate:
        float2 normuv = (in.texCoord - texOrigin) / texSize;
        float2 uv = in.texCoord;

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

    /*
    // Sample texture color
    float4 color = tex.sample(sam, uv);

    // Convert to grayscale (luminance)
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));

    // Green tint (you can tweak this for different greens)
    float3 greenTint = float3(0.6, 1.0, 0.6); // green glow

    // Apply green tint to luminance
    float3 green = luminance * greenTint;
    // green *= 0.9 + 0.1 * sin(in.texCoord.y * 800.0); // horizontal scanline modulation

    return float4(green, 1.0);
    */
}

fragment float4 fragment_ripple(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                constant Uniforms& uniforms [[buffer(0)]],
                                sampler sam [[sampler(0)]]) {

    float2 uv = in.texCoord;

    if (uniforms.intensity > 0.0) {

        float2 dir = uv - uniforms.mouse;
        float dist = length(dir);

        // Ripple parameters
        float waveFreq = 60.0;      // More ripples
        float waveSpeed = 10.0;
        float waveAmp = 0.005 * uniforms.intensity;      // Stronger distortion
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
        // return float4(0.0,0.5,1.0,0.5);
    }
    return tex.sample(sam, uv);
    // return float4(0.5,1.0,0.5,0.5);
}
