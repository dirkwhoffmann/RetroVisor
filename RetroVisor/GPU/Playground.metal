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

struct MyUniforms {

    uint2  maskSpacing;   // distance between dot centers (x, y)
    float2 dotSize;       // size of ellipse/diamond in pixels
    float  softness;      // glow softness factor
    uint   shape;         // 0 = ellipse, 1 = diamond
};

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

inline float shapeMask(float2 pos, constant MyUniforms& uniforms)
{
    // Normalize position into [-1..1] range relative to dotSize
    float2 uv = pos / uniforms.dotSize;

    if (uniforms.shape == 0) {
        // Ellipse: inside if uv.x^2 + uv.y^2 <= 1
        return saturate(1.0 - length(uv));
    } else {
        // Diamond: L1 norm (Manhattan distance)
        return saturate(1.0 - (abs(uv.x) + abs(uv.y)));
    }
}

constant MyUniforms u = { uint2(12,12), 16, 9, 0 };

kernel void playground1(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                        texture2d<half, access::write>  outTexture [[ texture(1) ]],
                        constant Uniforms               &uniforms  [[ buffer(0)  ]],
                        sampler                         sam        [[ sampler(0) ]],
                        uint2                           gid        [[ thread_position_in_grid ]])
{
    // Normalize gid to 0..1 in output texture
    // float2 uvOut = (float2(gid) + 0.5) / float2(outTexture.get_width(), outTexture.get_height());

    // Remap to texRect in input texture
    // float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    //
    // Experimental...
    //


    // uint width = inTexture.get_width();
    // uint height = inTexture.get_height();

    // Find which dot cell we are in
     uint2 cell = gid / u.maskSpacing;
     float2 center = float2(cell * u.maskSpacing) + float2(u.maskSpacing) * 0.5;

     // Position relative to current dot center
     float2 rel = float2(gid) - center;

     // Horizontal blending: also consider left & right neighbors
     float2 leftCenter  = center - float2(u.maskSpacing.x, 0.0);
     float2 rightCenter = center + float2(u.maskSpacing.x, 0.0);

     float2 relLeft  = float2(gid) - leftCenter;
     float2 relRight = float2(gid) - rightCenter;

     // Mask contributions
     float m0 = shapeMask(rel, u);
     float mL = shapeMask(relLeft, u);
     float mR = shapeMask(relRight, u);

     // Combine with horizontal glow (soft blending)
     float glow = m0 + exp(-length(relLeft) / u.softness) * mL + exp(-length(relRight) / u.softness) * mR;
     // float glow = m0;

     // Clamp
     glow = saturate(glow);

     // Output (for now just grayscale, later modulate with input image color & size)
     outTexture.write(half4(half3(glow, 0, 0), 1.0), gid);
}

kernel void playground2(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                        texture2d<half, access::sample> dotmask    [[ texture(1) ]],
                        texture2d<half, access::write>  outTexture [[ texture(2) ]],
                        constant Uniforms               &uniforms  [[ buffer(0)  ]],
                        sampler                         s          [[ sampler(0) ]],
                        uint2                           gid        [[ thread_position_in_grid ]])
{
    // Normalize gid to 0..1 in output texture
    float2 uvOut = (float2(gid) + 0.5) / float2(outTexture.get_width(), outTexture.get_height());

    // Remap to texRect in input texture
    float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    // Read from input image and convert to gray
    half4 color = inTexture.sample(s, uvIn);
    float gray = dot(color.rgb, half3(0.299, 0.587, 0.114));
    half4 grayColor = half4(gray, gray, gray, color.a);

    // Sample input texture using normalized coords
    half4 dm = dotmask.sample(s, uvOut);
    // dm = dm * 0.5 + 0.5;

    // For now, just pass through...
    grayColor = dm;

    // Write to output
    outTexture.write(grayColor, gid);
}
