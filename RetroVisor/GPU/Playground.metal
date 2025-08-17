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

// Reads a single pixel at integer coordinate gid
inline half4 sample(texture2d<half, access::sample> inTexture,
                    texture2d<half, access::write> outTexture,
                    constant Uniforms& uniforms,
                    sampler sam,
                    uint2 gid)
{
    // Normalize gid to 0..1 in output texture
    float2 uvOut = (float2(gid) + 0.5) /
                   float2(outTexture.get_width(), outTexture.get_height());

    // Remap to texRect in input texture
    float2 uvIn = uniforms.texRect.xy +
                  uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    // Sample input texture using normalized coords
    return inTexture.sample(sam, uvIn);
}

inline float shapeMask(float2 pos, float2 dotSize, constant PlaygroundUniforms& uniforms)
{
    // Normalize position into [-1..1] range relative to dotSize
    float2 uv = pos / dotSize;

    int shape = 0;

    if (shape == 0) {
        // Ellipse: inside if uv.x^2 + uv.y^2 <= 1
        return saturate(1.0 - length(uv));
    } else {
        // Diamond: L1 norm (Manhattan distance)
        return saturate(1.0 - (abs(uv.x) + abs(uv.y)));
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

kernel void playground2(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                        texture2d<half, access::sample> dotmask    [[ texture(1) ]],
                        texture2d<half, access::write>  outTexture [[ texture(2) ]],
                        constant Uniforms               &uniforms  [[ buffer(0)  ]],
                        constant PlaygroundUniforms     &u         [[ buffer(1)  ]],
                        sampler                         sam        [[ sampler(0) ]],
                        uint2                           gid        [[ thread_position_in_grid ]])
{
    //
    // Experimental...
    //

    float2 texSize = float2(inTexture.get_width(), inTexture.get_height());

    // half3 colorAtCenter = inTexture.sample(s, uvCenter).rgb;


    // Find which dot cell we are in
    uint2 maskSpacing = uint2(uint(u.GRID_WIDTH), uint(u.GRID_HEIGHT));
    float2 dotSize = float2(u.DOT_WIDTH, u.DOT_HEIGHT);

    uint2 cell = gid / maskSpacing;
    float2 center = float2(cell * maskSpacing) + float2(maskSpacing) * 0.5;
    float2 leftCenter  = center - float2(maskSpacing.x, 0.0);
    float2 rightCenter = center + float2(maskSpacing.x, 0.0);

    // Sample the image at the centers
    half3 colorAtCenter = half3(inTexture.sample(sam, center / texSize));
    half3 colorAtLeftCenter = half3(inTexture.sample(sam, leftCenter / texSize));
    half3 colorAtRightCenter = half3(inTexture.sample(sam, rightCenter / texSize));

    // Convert to brightness
    float weight = colorAtCenter.r; //  luminance(colorAtCenter);
    float weightL = colorAtLeftCenter.r;
    float weightR = colorAtRightCenter.r;
    weight = 0.75 * weight + 0.25 * weightL;

    // ---- Step 2: scale dot size based on weight ----
    float2 scaledDotSize = dotSize * weight;
    float2 scaledDotSizeL = dotSize * weightL;
    float2 scaledDotSizeR = dotSize * weightR;

    // Position relative to current dot centers
    float2 rel = float2(gid) - center;
    float2 relLeft  = float2(gid) - leftCenter;
    float2 relRight = float2(gid) - rightCenter;

    // Mask contributions
    float m0 = shapeMask(rel, scaledDotSize, u);
    float mL = shapeMask(relLeft, scaledDotSizeL, u);
    float mR = shapeMask(relRight, scaledDotSizeR, u);

    // Combine with horizontal glow (soft blending)
    // float glow = m0 + exp(-length(relLeft) / u.GLOW) * mL + exp(-length(relRight) / u.GLOW) * mR;
    float glow = m0 + mL + mR;

    // Clamp
    glow = saturate(glow);

    // Modulate final glow by input color
    half3 result = colorAtCenter * half(glow);

    // Output (for now just grayscale, later modulate with input image color & size)
    outTexture.write(half4(result, 1.0), gid);
}
