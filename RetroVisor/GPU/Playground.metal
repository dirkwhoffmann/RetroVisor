// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#include <metal_stdlib>
#include "ShaderTypes.metal"

using namespace metal;

//
// This is my personal playground. Haters back off!
//

// Fast Padé approximation for the Minkowski norm (|u|^n + |v|^n)^(1/n)
inline float minkowski(float2 uv, float n)
{
    float2 a = abs(uv);
    float m = max(a.x, a.y);
    if (m == 0.0f) return 0.0f;

    float l = min(a.x, a.y);
    float t = l / m;

    // s = t^n  (use fast log2/exp2; clamp to avoid log2(0))
    float s = fast::exp2(n * fast::log2(max(t, 1e-8f)));

    float invn = 1.0f / n;
    float A = 0.5f * (1.0f + invn); // (n+1)/(2n)
    float B = 0.5f * (1.0f - invn); // (n-1)/(2n)

    float g = (1.0f + A * s) / (1.0f + B * s);
    return m * g;
}

inline float superellipseLenApprox(float2 uv, float n)
{
    float2 a = abs(uv);

    float m = max(a.x, a.y);
    float l = min(a.x, a.y);

    float k = exp2(1.0f / n) - 1.0f;

    return m + k * l;
}

inline float shapeMask(float2 pos, float2 dotSize, constant PlaygroundUniforms& uniforms)
{
    // Normalize position into [-1..1] range relative to dotSize
    float2 uv = pos / dotSize;

    // Compute the distance via the Minkowski norm (1 = Manhattan, 2 = Euclidean)
    float len = minkowski(uv, uniforms.SHAPE);

    // Blur the edge
    if (len > (1.0 - uniforms.FEATHER)) {
        return smoothstep(1.0 + uniforms.FEATHER, 1.0 - uniforms.FEATHER, len);
    } else {
        return 1.0;
    }
}

kernel void playground1(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                        texture2d<half, access::write>  image      [[ texture(1) ]],
                        texture2d<half, access::write>  dotmask    [[ texture(2) ]],
                        constant Uniforms               &uniforms  [[ buffer(0)  ]],
                        constant PlaygroundUniforms     &u         [[ buffer(1)  ]],
                        sampler                         sam        [[ sampler(0) ]],
                        uint2                           gid        [[ thread_position_in_grid ]])
{
    // Normalize gid to 0..1 in output texture
    float2 uvOut = (float2(gid) + 0.5) / float2(image.get_width(), image.get_height());

    // Remap to texRect in input texture
    float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    // Sample input texture using normalized coords
    half4 color = inTexture.sample(sam, uvIn);

    image.write(color, gid);
    dotmask.write(color, gid);
}

inline float2 remap(float2 uv, float2 rect, float4 texRect)
{
    // Normalize gid to 0..1 in rect
    float2 uvOut = (float2(uv) + 0.5) / rect;

    // Remap to texRect in input texture
    return texRect.xy + uvOut * (texRect.zw - texRect.xy);
}

kernel void playground2(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                        texture2d<half, access::sample> blur       [[ texture(1) ]],
                        texture2d<half, access::write>  outTexture [[ texture(2) ]],
                        constant Uniforms               &uniforms  [[ buffer(0)  ]],
                        constant PlaygroundUniforms     &u         [[ buffer(1)  ]],
                        sampler                         sam        [[ sampler(0) ]],
                        uint2                           gid        [[ thread_position_in_grid ]])
{

    /* DISPLAY BLUR TEXTURE
    // Normalize gid to 0..1 in output texture
    float2 uvOut = (float2(gid) + 0.5) / float2(outTexture.get_width(), outTexture.get_height());

    // Remap to texRect in input texture
    float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    // Sample input texture using normalized coords
    half4 c = blur.sample(sam, uvIn);
    outTexture.write(c, gid);
    return;
    */

    //
    // Experimental...
    //

    // float2 inize = float2(inTexture.get_width(), inTexture.get_height());
    float2 outSize = float2(outTexture.get_width(), outTexture.get_height());


    // half4 color = inTexture.sample(sam, remap(float2(gid), outSize, uniforms.texRect));

    // Find the dot cell we are in
    uint2 maskSpacing = uint2(uint(u.GRID_WIDTH), uint(u.GRID_HEIGHT));

    // uint2 cell = gid / maskSpacing;
    float2 center = float2(uint2(gid / maskSpacing) * maskSpacing) + float2(maskSpacing) * 0.5;
    float2 centerL = center - float2(maskSpacing.x, 0.0);
    float2 centerR = center + float2(maskSpacing.x, 0.0);

    // Get the center weights from the blurred image
    half3 centerWeight = half3(blur.sample(sam, remap(center, outSize, uniforms.texRect)));
    half3 centerWeightL = half3(blur.sample(sam, remap(centerL, outSize, uniforms.texRect)));
    half3 centerWeightR = half3(blur.sample(sam, remap(centerR, outSize, uniforms.texRect)));

    // Convert to brightness
    float weight = centerWeight.r; //  luminance(colorAtCenter);
    float weightL = centerWeightL.r;
    float weightR = centerWeightR.r;
    weight = weight; // 0.25 * weightL + 0.5 * weight + 0.25 * weightR;

    // Scale dot size based on weight
    float2 minDotSize = float2(u.MIN_DOT_WIDTH, u.MIN_DOT_HEIGHT);
    float2 maxDotSize = float2(u.MAX_DOT_WIDTH, u.MAX_DOT_HEIGHT);
    float2 scaledDotSize = mix(minDotSize, maxDotSize, weight);
    float2 scaledDotSizeL = mix(minDotSize, maxDotSize, weightL);
    float2 scaledDotSizeR = mix(minDotSize, maxDotSize, weightR);

    // Compute relative position to dot centers
    /*
    float2 rel = float2(gid) - center;
    float2 relLeft  = float2(gid) - centerL;
    float2 relRight = float2(gid) - centerR;
    */

    // Compute mask contributions
    float m0 = shapeMask(float2(gid) - center, scaledDotSize, u);
    float mL = shapeMask(float2(gid) - centerL, scaledDotSizeL, u);
    float mR = shapeMask(float2(gid) - centerR, scaledDotSizeR, u);

    // Combine with horizontal glow (soft blending)
    // float glow = m0 + exp(-length(relLeft) / u.GLOW) * mL + exp(-length(relRight) / u.GLOW) * mR;
    float intensity = saturate(max(m0, m0 + mL + mR));

    // Clamp
    // glow = saturate(glow);

    // Modulate final glow by input color
    half3 result = pow(centerWeight, 4.01 - 2 * u.BRIGHTNESS) * half(intensity);

    // Output (for now just grayscale, later modulate with input image color & size)
    outTexture.write(half4(result, 1.0), gid);
}
