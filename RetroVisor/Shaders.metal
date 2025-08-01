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
    float2 center;
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

    if (uniforms.intensity > 0.0) {
        float2 uvMin = uniforms.texRect.xy;
            float2 uvMax = uniforms.texRect.zw;
            float2 localUV = (uv - uvMin) / (uvMax - uvMin);

            float2 dir = localUV - uniforms.center;
            float dist = length(dir);
            float ripple = uniforms.intensity * 0.015 * sin(30.0 * dist - uniforms.time * 10.0);
            localUV += normalize(dir) * ripple;

            uv = mix(uvMin, uvMax, localUV);
    }

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
}

