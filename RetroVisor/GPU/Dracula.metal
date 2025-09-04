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
#include "ColorToolbox.metal"
#include "MathToolbox.metal"

using namespace metal;

namespace dracula {

    struct Uniforms {

        // Texture dimensions
        float INPUT_TEX_SCALE;
        float OUTPUT_TEX_SCALE;
        uint  RESAMPLE_FILTER;

        // Chroma phase
        uint  PAL;
        float GAMMA_INPUT;
        float GAMMA_OUTPUT;
        float CHROMA_RADIUS;

        // Bloom effect
        uint  BLOOM_ENABLE;
        uint  BLOOM_FILTER;
        float BLOOM_THRESHOLD;
        float BLOOM_INTENSITY;
        float BLOOM_RADIUS_X;
        float BLOOM_RADIUS_Y;

        // Dot mask
        uint  DOTMASK_ENABLE;
        uint  DOTMASK_TYPE;
        uint  DOTMASK_MODE;
        float DOTMASK_WIDTH;
        float DOTMASK_SHIFT;
        float DOTMASK_WEIGHT;
        float DOTMASK_SATURATION;
        float DOTMASK_BRIGHTNESS;
        float DOTMASK_BLUR;
        float DOTMASK_MIX;
        float DOTMASK_GAIN;
        float DOTMASK_LOOSE;

        // Scanlines
        uint  SCANLINES_ENABLE;
        float SCANLINE_DISTANCE;
        float SCANLINE_SHARPNESS;
        float SCANLINE_BLOOM;
        float SCANLINE_WEIGHT1;
        float SCANLINE_WEIGHT2;
        float SCANLINE_WEIGHT3;
        float SCANLINE_WEIGHT4;
        float SCANLINE_WEIGHT5;
        float SCANLINE_WEIGHT6;
        float SCANLINE_WEIGHT7;
        float SCANLINE_WEIGHT8;
        float SCANLINE_BRIGHTNESS;
        
        // Debugging
        uint  DEBUG_ENABLE;
        uint  DEBUG_TEXTURE;
        float DEBUG_SLIDER;
    };
    
    //
    // RGB to YUV/YIQ converter
    //

    kernel void colorSpace(texture2d<half, access::sample> inTex     [[ texture(0) ]],
                           texture2d<half, access::write>  linTex    [[ texture(1) ]],
                           texture2d<half, access::write>  yccTex    [[ texture(2) ]],
                           constant Uniforms               &u        [[ buffer(0)  ]],
                           sampler                         sam       [[ sampler(0) ]],
                           uint2                           gid       [[ thread_position_in_grid ]])
    {
        // Get size of output textures
        const Coord2 rect = float2(linTex.get_width(), linTex.get_height());

        // Normalize gid to 0..1 in rect
        Coord2 uv = (Coord2(gid) + 0.5) / rect;

        // Read pixel
        Color3 rgb = pow(Color3(inTex.sample(sam, uv).rgb), Color3(u.GAMMA_INPUT));
        linTex.write(Color4(rgb, 1.0), gid);
        
        // Split components
        Color3 ycc = u.PAL == 1 ? RGB2YUV(rgb) : RGB2YIQ(rgb);
        yccTex.write(Color4(ycc, 1.0), gid);
    }

    /*
    inline float3 brightPass(float3 color, float luma, float threshold, float intensity) {

        // Keep only if brighter than threshold
        float mask = smoothstep(threshold, threshold + 0.1, luma);

        // Scale the bright part
        return color * mask * intensity;
    }
    */
    
    float dotMaskWeight(uint2 gid, Coord2 shift, constant Uniforms &u) {
        
        // Setup the grid cell
        uint2 gridSize = uint2(uint(u.DOTMASK_WIDTH), uint(u.DOTMASK_WIDTH));
        uint2 gridRange = uint2(gridSize.x - 1, gridSize.y - 1);

        // Shift gid
        Coord2 shiftedGid = Coord2(gid + uint2(shift * u.DOTMASK_WIDTH));

        // Normalize gid relative to the surrounding grid cell
        Coord2 nrmgid = fmod(shiftedGid, Coord2(gridSize)) / Coord2(gridRange);

        // Make (0,0) the new center coordinate
        nrmgid -= Coord2(0.5, 0.5);

        // Compute distance to the center
        Coord length = max(0.0, (abs(nrmgid.x)));
        
        // Translate distance to a weight
        float weight = smoothstep(u.DOTMASK_WEIGHT, 0.0, length);
         
        return weight;
    }
    
    kernel void dotMask(texture2d<half, access::sample> input     [[ texture(0) ]],
                        texture2d<half, access::write>  output    [[ texture(1) ]],
                        constant Uniforms               &u        [[ buffer(0)  ]],
                        sampler                         sam       [[ sampler(0) ]],
                        uint2                           gid       [[ thread_position_in_grid ]])
    {
        Color r = dotMaskWeight(gid, Coord2(0, 0), u);
        Color g = dotMaskWeight(gid, Coord2(u.DOTMASK_SHIFT, 0), u);
        Color b = dotMaskWeight(gid, Coord2(2 * u.DOTMASK_SHIFT, 0), u);
            
        output.write(Color4(r, g, b, 1.0), gid);
    }

    kernel void composite(texture2d<half, access::sample> ycc       [[ texture(0) ]],
                          texture2d<half, access::sample> dotMask   [[ texture(1) ]],
                          texture2d<half, access::write>  outTex    [[ texture(2) ]],
                          texture2d<half, access::write>  brightTex [[ texture(3) ]],
                          constant Uniforms               &u        [[ buffer(0)  ]],
                          sampler                         sam       [[ sampler(0) ]],
                          uint2                           gid       [[ thread_position_in_grid ]])
    {
        uint W = outTex.get_width();
        uint H = outTex.get_height();
        if (gid.x >= W || gid.y >= H) return;

        // Read pixel
        Color4 yccC = ycc.read(gid);

        // Search the maximum chroma value in surrounding pixels
        int radius = u.CHROMA_RADIUS;
        Color maxU = yccC.y, maxV = yccC.z;
        int maxDxU = 0, maxDxV = 0;

        for (int dx = -radius; dx <= radius; dx++) {

            if (dx == 0) continue;
            int x = clamp(int(gid.x) + dx, 0, int(W - 1));
            Color4 sample = ycc.read(uint2(x, gid.y));

            if (sample.y > maxU) { maxU = sample.y; maxDxU = abs(dx); }
            if (sample.z > maxV) { maxV = sample.z; maxDxV = abs(dx); }
        }

        // Interpolation weights based on distance
        float distU = float(maxDxU) / float(max(1, radius));
        float distV = float(maxDxV) / float(max(1, radius));
        Color uOut = mix(yccC.y, maxU, Color(smoothstep(0.0, 1.0, 1.0 - distU)));
        Color vOut = mix(yccC.z, maxV, Color(smoothstep(0.0, 1.0, 1.0 - distV)));

        // Recombine with luma and convert back to RGB
        Color3 combined = Color3(yccC.x, uOut, vOut);
        Color3 rgb = u.PAL ? YUV2RGB(combined) : YIQ2RGB(combined);

        // Write pixel
        // outTex.write(half4(half3(rgb), 1.0), gid);

        //
        //
        //

        half4 color = half4(half3(rgb), 1.0);
        
        outTex.write(color, gid);

        //
        // Brightness pass
        //

        if (u.BLOOM_ENABLE) {

            // Compute luminance
            Color Y = dot(rgb, Color3(0.299, 0.587, 0.114));

            // Keep only if brighter than threshold
            half3 mask = half3(smoothstep(u.BLOOM_THRESHOLD, u.BLOOM_THRESHOLD + 0.1, float3(Y)));

            // Scale the bright part
            brightTex.write(half4(color.rgb * mask * u.BLOOM_INTENSITY, 1.0), gid);
        }
    }

    half4 scanline(half4 x, float weight) {
        
        return pow(x, pow(mix(0.8, 1.2, weight), 8));
    }

    /*
    
    inline float wrap01(float x) { return x - floor(x); }           // like fract()
    inline float wrapSigned(float x) { return x - floor(x + 0.5f); } // to [-0.5, 0.5)

    // Shortest-arc interpolation on the hue circle (h in [0,1))
    inline float hue_lerp(float h0, float h1, float t)
    {
        float d = wrapSigned(h1 - h0);    // now d is in [-0.5, 0.5]
        return wrap01(h0 + t * d);
    }

    inline float hue_shift(float h0, float h1, float t)
    {
        if (abs(h0 - h1) > 0.5) {
            h1 += h1 < h0 ? 0.5 : -0.5;
        }
        return h0 + t * (h1 - h0);
    }
    */
    
    kernel void crt(texture2d<half, access::sample> inTex     [[ texture(0) ]],
                    texture2d<half, access::sample> ycc       [[ texture(1) ]],
                    texture2d<half, access::sample> dotMask   [[ texture(2) ]],
                    texture2d<half, access::sample> bloomTex  [[ texture(3) ]],
                    texture2d<half, access::write>  outTex    [[ texture(4) ]],
                    constant Uniforms               &u        [[ buffer(0)  ]],
                    sampler                         sam       [[ sampler(0) ]],
                    uint2                           gid       [[ thread_position_in_grid ]])
    {
        // float2 size = float2(outTex.get_width(), outTex.get_height());

        // Normalize gid to 0..1 in output texture
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(outTex.get_width(), outTex.get_height());

        // Read image pixel
        Color4 color = inTex.sample(sam, uv);
        
        // Apply bloom effect
        /*
        if (u.BLOOM_ENABLE) {

            Color4 bloom = bloomTex.sample(sam, uv);
            color = saturate(color + bloom);
        }
        */
        
        // Apply scanline effect (if emulation type matches)
        if (u.SCANLINES_ENABLE) {
            
            uint line = gid.y % uint(u.SCANLINE_DISTANCE);
            
            Color4 col = inTex.sample(sam, uv);
            Color4 col2 = inTex.sample(sam, uv, level(u.SCANLINE_SHARPNESS));
            col = mix(col, col2, u.SCANLINE_BLOOM);
            
            if (line == 0) {
                color = scanline(col, u.SCANLINE_WEIGHT1);
            } else if (line == 1) {
                color = scanline(col, u.SCANLINE_WEIGHT2);
            } else if (line == 2) {
                color = scanline(col, u.SCANLINE_WEIGHT3);
            } else if (line == 3) {
                color = scanline(col, u.SCANLINE_WEIGHT4);
            } else if (line == 4) {
                color = scanline(col, u.SCANLINE_WEIGHT5);
            } else if (line == 5) {
                color = scanline(col, u.SCANLINE_WEIGHT6);
            } else if (line == 6) {
                color = scanline(col, u.SCANLINE_WEIGHT7);
            } else if (line == 7) {
                color = scanline(col, u.SCANLINE_WEIGHT8);
            }
        }

        // Apply dot mask effect
        if (u.DOTMASK_ENABLE) {

            Color4 mask = dotMask.sample(sam, uv, level(u.DOTMASK_BLUR));
            // mask += dotMask.sample(sam, uv, level(u.DOTMASK_BLUR));
            // mask = Color4(sigmoid(mask.rgb, u.DOTMASK_BRIGHTNESS), 1.0);

            
            // REMOVE ASAP
            //outTex.write(mask, gid);
            // return;
            
            if (u.DOTMASK_MODE == 0) {
                
                // Multiply
                color = color * (u.DOTMASK_MIX * mask + (1 - u.DOTMASK_MIX));
                // color *= u.DOTMASK_BRIGHTNESS;
                
            } else if (u.DOTMASK_MODE == 1) {
                
                // Blend
                color = mix(color, mask, u.DOTMASK_MIX);
                
            } else if (u.DOTMASK_MODE == 2) {
                
                Color4 gain = min(color, 1 - color) * mask;
                Color4 loose = min(color, 1 - color) * 0.5 * (1 - mask);
                color += u.DOTMASK_GAIN * gain - u.DOTMASK_LOOSE * loose;
            }
        }

        outTex.write(pow(color, Color4(1.0 / u.GAMMA_OUTPUT)), gid);
        return;
    }

    kernel void debug(texture2d<half, access::sample> src       [[ texture(0) ]],
                      texture2d<half, access::sample> ycc       [[ texture(1) ]],
                      texture2d<half, access::sample> dotMask   [[ texture(2) ]],
                      texture2d<half, access::sample> bloomTex  [[ texture(3) ]],
                      texture2d<half, access::write>  final     [[ texture(4) ]],
                      constant Uniforms               &u        [[ buffer(0)  ]],
                      sampler                         sam       [[ sampler(0) ]],
                      uint2                           gid       [[ thread_position_in_grid ]])
    {
        // Normalize gid to 0..1 in output texture
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(final.get_width(), final.get_height());

        if (gid.x >= u.DEBUG_SLIDER * final.get_width()) {

            Color4 color;

            switch(u.DEBUG_TEXTURE) {

                case 0:

                    color = src.sample(sam, uv);
                    break;

                case 1:

                    color = ycc.sample(sam, uv);
                    color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                    break;

                case 2:

                    color = ycc.sample(sam, uv, level(1));
                    color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                    break;

                case 3:

                    color = ycc.sample(sam, uv, level(2));
                    color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                    break;

                case 4:

                    color = ycc.sample(sam, uv, level(3));
                    color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                    break;

                case 5:

                    color = ycc.sample(sam, uv, level(4));
                    color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                    break;

                case 6:

                    color = ycc.sample(sam, uv).xxxw;
                    break;

                case 7:

                    color = ycc.sample(sam, uv);
                    color = Color4(1.0, color.y, 0.0, color.w);
                    color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                    break;

                case 8:

                    color = ycc.sample(sam, uv);
                    color = Color4(1.0, 0.0, color.z, color.w);
                    color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                    break;

                case 9:
                    color = dotMask.sample(sam, uv, level(u.DOTMASK_BLUR));
                    // color = dotMask.sample(sam, uv);
                    break;
                    
                default:

                    color = bloomTex.sample(sam, uv);
                    break;
            }
            
            final.write(color, gid);
            return;
        }
    }
}
