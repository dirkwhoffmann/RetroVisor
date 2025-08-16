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

kernel void playground1(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                        texture2d<half, access::write>  outTexture [[ texture(1) ]],
                        constant Uniforms               &uniforms  [[ buffer(0)  ]],
                        sampler                         s          [[ sampler(0) ]],
                        uint2                           gid        [[ thread_position_in_grid ]])
{
    /*
    // Normalize gid to 0..1 in output texture
    float2 uvOut = (float2(gid) + 0.5) / float2(outTexture.get_width(), outTexture.get_height());

    // Remap to texRect in input texture
    float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    // Sample input texture using normalized coords
    half4 result = inTexture.sample(s, uvIn);
    */

    //
    // Experimental...
    //

    // Grid spacing
    const float spacing = 6.0;

    // Find the nearest bubble center (multiples of spacing)
    float2 pos = float2(gid);
    float2 nearestCenter = round(pos / spacing) * spacing;

    // Distance to the bubble center
    float dist = length(pos - nearestCenter);

    // Radius of influence (half spacing)
    float radius = spacing * 0.5;

    // Value: 1.0 at the center, fades to 0 at the edge
    float value = saturate(1.0 - (dist / radius));

    // Write grayscale bubble mask
    outTexture.write(half4(value, value, value, 1.0), gid);
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

    // Sample input texture using normalized coords
    half4 dm = dotmask.sample(s, uvOut);
    dm = dm * 0.5 + 0.5;

    half4 result = inTexture.sample(s, uvIn);
    result.gb = 0;
    
    result *= dm;

    // Write to output
    outTexture.write(result, gid);
}
