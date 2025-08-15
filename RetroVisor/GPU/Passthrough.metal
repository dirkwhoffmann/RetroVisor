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
// Passthrogh kernel
//

kernel void bypass(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                   texture2d<half, access::write>  outTexture [[ texture(1) ]],
                   constant Uniforms               &uniforms  [[ buffer(0) ]],
                   sampler                         s          [[ sampler(0) ]],
                   uint2                           gid        [[ thread_position_in_grid ]])
{
    // Normalize gid to 0..1 in output texture
    float2 uvOut = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());

    // Remap to texRect in input texture
    float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

    // Sample input texture using normalized coords
    half4 result = inTexture.sample(s, uvIn);

    // Write to output
    outTexture.write(result, gid);
}
