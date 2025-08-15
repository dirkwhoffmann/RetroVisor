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

fragment float4 fragment_secret(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                constant Uniforms& uniforms [[buffer(0)]],
                                sampler sam [[sampler(0)]]) {

    float2 shift = float2(0.5 - 0.5 / uniforms.zoom, 0.5 - 0.5 / uniforms.zoom);
    float2 uv = in.texCoord / uniforms.zoom + shift;

    uv = uv.yx;
    return tex.sample(sam, uv);
}
