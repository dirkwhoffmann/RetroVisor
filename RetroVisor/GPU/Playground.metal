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

// Returns a value in [0,1]: 1 inside the ellipse, fading outside
float ellipseMask(float2 point, float2 center, float2 radius, float edgeWidth)
{
    // Vector from center to point
    float2 delta = point - center;

    // Scale into unit circle space
    float2 scaled = delta / radius;

    // Distance in ellipse space
    float len = length(scaled);

    // Distance from center to ellipse border along this direction
    float distanceToBorder = length(delta) / len;

    // Compute mask: 1 inside, fade outside
    float d = length(delta);
    return 1.0 - smoothstep(distanceToBorder, distanceToBorder + edgeWidth, d);
}

kernel void playground1(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                        texture2d<half, access::write>  outTexture [[ texture(1) ]],
                        constant Uniforms               &uniforms  [[ buffer(0)  ]],
                        sampler                         sam        [[ sampler(0) ]],
                        uint2                           gid        [[ thread_position_in_grid ]])
{
    // Normalize gid to 0..1 in output texture
    float2 uvOut = (float2(gid) + 0.5) / float2(outTexture.get_width(), outTexture.get_height());

    // Remap to texRect in input texture
    float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    // Sample input texture using normalized coords
    // half4 result = inTexture.sample(s, uvIn);

    //
    // Experimental...
    //

    uint width = inTexture.get_width();
    // uint height = inTexture.get_height();
    float beamWidth = 4.0;

    half3 color = half3(0.0);

    /*
    float totalWeight = 0.0;

    int N = int(beamWidth);
    float texelSizeX = 1.0 / float(width);

    // Horizontal smear
    for (int i = -N; i <= N; ++i) {
        float offset = float(i);
        float w = exp(-0.5 * (offset / beamWidth) * (offset / beamWidth));
        float2 sampleUV = uvIn + float2(offset * texelSizeX, 0.0);
        color += half3(inTexture.sample(sam, sampleUV)) * w;
        totalWeight += w;
    }

    color /= totalWeight;
    */
    color = half3(inTexture.sample(sam, uvIn));

    float maskSpacingX = 6;
    float maskSpacingY = 8;
    float bubbleRadius = .5;

    // Compute mask pattern coordinates
    float2 maskUV = float2(gid) / float2(maskSpacingX, maskSpacingY);

    // Calculate distance to nearest bubble center
    float2 nearestCenter = floor(maskUV) + 0.5;
    float2 delta = maskUV - nearestCenter;
    float dist = length(delta);

    maskUV = fract(maskUV);

    float bubble = ellipseMask(maskUV, float2(0.5,0.5), float2(0.15, 0.4), 0.3);

    /*
    // Circular bubble falloff
    float bubble = smoothstep(bubbleRadius, 0.0, dist);

    // Modulate original color by bubble intensity
    half3 outColor = color.rgb * half(bubble);
*/
    half3 outColor = half3(bubble,bubble,bubble);
    outTexture.write(half4(outColor, 1.0), gid);
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
