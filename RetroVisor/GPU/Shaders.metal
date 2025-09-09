// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#include <metal_stdlib>

#include "MathToolbox.metal"

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
    uint resample;
    float2 resampleXY;
    uint debug;
    uint debugPos;
    float3 debugColor;
    float2 debugXY;
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
 * Responsibilities:
 *
 *  - Applies an optional zoom effect (magnification feature)
 *  - Applies an optional water-ripple effect (window animation effect)
 *  - Mixes the effect texture with the original texture (in debug mode)
 *  - Draws the final texture onto a fullscreen quad
 */

inline float2 debugWeight(float2 uv, constant Uniforms &u) {
    
    constexpr float2 signs[4] = {
        
        float2( 1.0,  1.0), // Upper left
        float2(-1.0,  1.0), // Upper right
        float2( 1.0, -1.0), // Lower left
        float2(-1.0, -1.0)  // Lower right
    };
    
    float2 s = signs[(u.debug - 1) & 3];
    float2 xy = select(u.debugXY, 1.0 - u.debugXY, s < 0);
    return s * (uv - xy);
}

inline float4 sampleFragment(float2 uv,
                             texture2d<float> orig,
                             texture2d<float> tex,
                             constant Uniforms& uniforms,
                             sampler sam) {
        
    // Quick-exit if debug mode is disabled
    if (uniforms.debug == 0) return tex.sample(sam, uv);
        
    float2 w = debugWeight(uv, uniforms);
    
    bool inside = w.x < 0 && w.y < 0;
    bool border = inside && (abs(w.x) < 0.002 || abs(w.y) < 0.002);
    
    if (border) {
        return float4(uniforms.debugColor, 1.0);
    } else if (inside) {
        return tex.sample(sam, uv);
    } else {
        return orig.sample(sam, uv);
    }
}
    
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> orig [[texture(0)]],
                              texture2d<float> tex [[texture(1)]],
                              constant Uniforms& uniforms [[buffer(0)]],
                              sampler sam [[sampler(0)]]) {

    // Scale and shift coordinate according to the given zoom and parameters
    float2 uv = in.texCoord / uniforms.zoom + uniforms.shift;
    float2 mouse = uniforms.mouse / uniforms.zoom + uniforms.shift;

    float4 result;
    
    // Apply the water-ripple effect if enabled
    if (uniforms.intensity > 0.0) {
        
        // Ripple parameters
        float waveFreq        = 100.0;
        float waveSpeed       = 10.0;
        float baseAmp         = 0.025 * uniforms.intensity;
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
        
        // float4 color = tex.sample(sam, rippleUV);
        float4 color = sampleFragment(rippleUV, orig, tex, uniforms, sam);
        float brightness = 1.0 - brightnessDepth * (cos((dist * variableFreq) - (uniforms.time * waveSpeed)) * 0.5 + 0.5);
        color.rgb *= brightness;
        
        return color;
    }

    return sampleFragment(uv, orig, tex, uniforms, sam);
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
