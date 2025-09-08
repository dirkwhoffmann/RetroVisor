// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#include <metal_stdlib>

using namespace metal;

struct VertexIn {

    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {

    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {

    float time;
    float2 shift;
    float zoom;
    float intensity;
    float2 resolution;
    float2 window;
    float2 center;
    float2 mouse;
};

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
// Fragment shader
//

/* The fragment shader used in the final render stage, where the computed
 * texture is drawn onto a fullscreen quad.
 *
 * Features:
 *
 *  - Applies an optional zoom effect (magnification feature)
 *  - Applies an optional water-ripple effect (window animation effect)
 *  - Draws the final texture onto a fullscreen quad
 */

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              constant Uniforms& uniforms [[buffer(0)]],
                              sampler sam [[sampler(0)]]) {

    // float2 shift = float2(0.5 - 0.5 / uniforms.zoom, 0.5 - 0.5 / uniforms.zoom);
    float2 uv = in.texCoord / uniforms.zoom + uniforms.shift;
    float2 mouse = uniforms.mouse / uniforms.zoom + uniforms.shift;

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

//
// Dot mask kernel (Used by DotMasLibrary)
//

struct DotMaskdUniforms {
    
    uint WIDTH;
    uint HEIGHT;
    uint TYPE;
    uint COLOR;
    uint SIZE;
    float SATURATION;
    float BRIGHTNESS;
    float BLUR;
};

kernel void dotMask(texture2d<half, access::sample> input     [[ texture(0) ]],
                    texture2d<half, access::write>  output    [[ texture(1) ]],
                    constant DotMaskdUniforms       &u        [[ buffer(0)  ]],
                    sampler                         sam       [[ sampler(0) ]],
                    uint2                           gid       [[ thread_position_in_grid ]])
{
    float2 texSize = float2(input.get_width(), input.get_height());
    uint2 gridSize = uint2(float2(u.SIZE, u.SIZE) * texSize);

    float2 uv = (float2(gid % gridSize) + 0.5) / float2(gridSize);

    half4 color = input.sample(sam, uv);
    output.write(color, gid);
}
