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
// Vertex shader
//

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

//
// Fragment shaders
//

fragment float4 fragment_ripple(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                constant Uniforms& uniforms [[buffer(0)]],
                                sampler sam [[sampler(0)]]) {

    float2 shift = float2(0.5 - 0.5 / uniforms.zoom, 0.5 - 0.5 / uniforms.zoom);
    float2 uv = in.texCoord / uniforms.zoom + shift;
    float2 mouse = uniforms.mouse / uniforms.zoom + shift;

    if (uniforms.intensity > 0.0) {

        // Ripple parameters
        float waveFreq        = 100.0; // 60
        float waveSpeed       = 10.0;
        float baseAmp         = 0.025 * uniforms.intensity; // 0.005
        float brightnessDepth = 0.15 * uniforms.intensity;
        float frequencyDrop   = 0.75;

        // Compute distance to the center
        float2 dir = uv - mouse;
        float dist = length(dir);

        // Make wavelength increase with distance
        float variableFreq = waveFreq / (1.0 + dist * frequencyDrop);

        // Lower the amplitude with distance
        float ampFalloff = exp(-dist * 0.5);
        float rippleAmp = baseAmp * ampFalloff;

        // Simulate ripple and displacement
        float ripple = sin((dist * variableFreq) - (uniforms.time * waveSpeed));
        float offset = ripple * rippleAmp;
        float2 rippleUV = uv + (dist > 0.0001 ? normalize(dir) * offset : float2(0.0));

        // Rectify the coordinates at the border
        rippleUV = clamp(rippleUV, float2(0.01), float2(0.99));

        float4 color = tex.sample(sam, rippleUV);
        float brightness = 1.0 - brightnessDepth * (cos((dist * variableFreq) - (uniforms.time * waveSpeed)) * 0.5 + 0.5);
        color.rgb *= brightness;

        return color;
    }

    return tex.sample(sam, uv);
}
