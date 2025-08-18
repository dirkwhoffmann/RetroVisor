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
/*
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
*/

/*
inline float shapeMask(float2 pos,
                       float2 dotSize,
                       constant PlaygroundUniforms& uniforms)
{
    // Normalize position into [-1..1] range relative to dotSize
    float2 uv = pos / dotSize;

    // Effective corner radius, relative to the smaller dimension
    float cornerRadius = uniforms.CORNER * min(dotSize.x, dotSize.y);
    // cornerRadius = 0;

    // Signed distance to rounded rectangle
    float2 d = abs(uv) - 1.0 + cornerRadius;
    float dist = length(max(d, 0.0)) - cornerRadius;

    // Soft mask: 1 inside, 0 outside, feathered edge
    // return saturate(1.0 - (abs(uv.x) + abs(uv.y)));
    // return dist <= 0 ? 1.0 : 0.0;
    return smoothstep(0.0, -uniforms.FEATHER, dist);
}
*/

/*
inline float shapeMask(float2 pos,
                       float2 radius,
                       constant PlaygroundUniforms& uniforms)
{
    // Normalize coordinates to [-1..1] relative to radius
    float2 uv = abs(pos) / radius;

    // Superellipse / rounded rect exponent
    float n = uniforms.CORNER; // n=2 -> ellipse, n>2 -> more rectangular

    // Distance metric for superellipse
    float dShape = pow(uv.x, n) + pow(uv.y, n);

    // Distance to border: positive inside, zero at boundary, negative outside
    float distToBorder = 1.0 - dShape;

    // Absolute feather size in normalized units
    float featherAbs = saturate(uniforms.FEATHER) * 1.0; // scale factor can be tuned

    // Feathered intensity based on distance to border
    float intensity;
    if (featherAbs > 0.0)
    {
        intensity = clamp(distToBorder / featherAbs, 0.0, 1.0);
    }
    else
    {
        // Hard cutoff
        intensity = distToBorder > 0.0 ? 1.0 : 0.0;
    }

    return intensity;
}
*/

#if 0
inline float shapeMask(float2 pos,
                       float2 radius,
                       constant PlaygroundUniforms& uniforms)
{
    int fadeMode = 2;
    int n = uniforms.CORNER;

    /*
    float2 uv = pos / radius;
        float d = pow(abs(uv.x), n) + pow(abs(uv.y), n); // normalized distance

        // Effective feather in absolute units
        float feather = uniforms.FEATHER * min(radius.x, radius.y);

        if (feather <= 0.0) {
            // Hard cutoff at boundary
            return d <= 1.0 ? 1.0 : 0.0;
        }

        if (fadeMode == 0) { // linear
            return clamp(1.0 - d / feather, 0.0, 1.0);
        } else if (fadeMode == 1) { // smoothstep
            return smoothstep(1.0, 0.0, d / feather);
        } else { // gaussian with hard cutoff fallback
            float g = exp(-(d * d) / (2.0 * feather * feather));
            // blend Gaussian with hard cutoff when very close to the boundary
            float hardCut = d <= 1.0 ? 1.0 : 0.0;
            // Use smoothstep to mix smoothly between Gaussian and hard cutoff
            float blendFactor = saturate(feather * 10.0); // small feather → blendFactor ~0 → hard cutoff
            return mix(hardCut, g, blendFactor);
        }
     */


    // normalize position into shape space
     float d = pow(abs(pos.x)/radius.x, uniforms.CORNER) + pow(abs(pos.y)/radius.y, uniforms.CORNER);

    // Effective feather based on radius (use smaller dimension for consistency)
    // float feather = uniforms.FEATHER * min(radius.x, radius.y);
    float feather = uniforms.FEATHER;

     // d = 0 at center, 1 at boundary
     if (fadeMode == 0) { // linear
         return clamp(1.0 - d/feather, 0.0, 1.0);
     } else if (fadeMode == 1) { // smoothstep
         return smoothstep(1.0, 0.0, d/feather);
     } else { // gaussian
         return exp(-(d*d)/(2.0*feather*feather));
     }

}
#endif


inline float shapeMask(float2 pos, float2 dotSize, constant PlaygroundUniforms& uniforms)
{
    // Normalize position into [-1..1] range relative to dotSize
    float2 uv = pos / dotSize;
    float len = length(uv);

    int shape = 0;

    if (shape == 0) {
        // Ellipse: inside if uv.x^2 + uv.y^2 <= 1
        // return saturate(1.0 - length(uv));
        // return smoothstep(1.0 * uniforms.FEATHER, 0.0, length(uv));
        if (len > (1.0 - uniforms.FEATHER)) {
            return smoothstep(1.0 + uniforms.FEATHER, 1.0 - uniforms.FEATHER, len);
        }
        return 1.0;
        // return saturate(1.0 - pow(length(uv), uniforms.FEATHER));
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


    half4 color = inTexture.sample(sam, remap(float2(gid), outSize, uniforms.texRect));

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

    // Position relative to current dot centers
    float2 rel = float2(gid) - center;
    float2 relLeft  = float2(gid) - centerL;
    float2 relRight = float2(gid) - centerR;

    // Mask contributions
    float m0 = shapeMask(rel, scaledDotSize, u);
    float mL = shapeMask(relLeft, scaledDotSizeL, u);
    float mR = shapeMask(relRight, scaledDotSizeR, u);

    // Combine with horizontal glow (soft blending)
    // float glow = m0 + exp(-length(relLeft) / u.GLOW) * mL + exp(-length(relRight) / u.GLOW) * mR;
    float glow = max(m0, m0 + mL + mR);

    // Clamp
    glow = saturate(glow);

    // Modulate final glow by input color
    half3 result = centerWeight * half(glow);
    // half3 result = color.rgb * half(glow);

    // Output (for now just grayscale, later modulate with input image color & size)
    outTexture.write(half4(result, 1.0), gid);
}
