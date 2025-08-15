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

kernel void bypass(texture2d<half, access::read>  inTexture  [[ texture(0) ]],
                   texture2d<half, access::write> outTexture [[ texture(1) ]],
                   constant Uniforms              &uniforms  [[ buffer(0) ]],
                   uint2                          gid        [[ thread_position_in_grid ]])
{
    // Bounds check (in case the dispatch grid is larger than the texture)
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    // 1. gid -> normalized coords (0..1) in output texture space
    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());

    // 2. Remap to input texture normalized space using texRect
    uv = uniforms.texRect.xy + uv * (uniforms.texRect.zw - uniforms.texRect.xy);

    // 3. Convert normalized coords to input texture pixel coords
    uint2 inCoords = uint2(uv * float2(inTexture.get_width(), inTexture.get_height()));

    // 4. Read from input and write to output
    half4 result = inTexture.read(inCoords);

    outTexture.write(result, gid);
}
