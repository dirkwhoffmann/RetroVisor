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

namespace phosbite {

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
        uint  DOTMASK_COLOR;
        uint  DOTMASK_SIZE;
        float DOTMASK_SATURATION;
        float DOTMASK_BRIGHTNESS;
        float DOTMASK_BLUR;
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
        uint  DEBUG_TEXTURE1;
        uint  DEBUG_TEXTURE2;
        uint  DEBUG_LEFT;
        uint  DEBUG_RIGHT;
        float DEBUG_SLICE;
        float DEBUG_MIPMAP;
    };
    
    //
    // RGB to YUV/YIQ converter
    //

    kernel void colorSpace(texture2d<half, access::sample> src [[ texture(0) ]], // RGB
                           texture2d<half, access::write>  lin [[ texture(1) ]], // Linear RGB
                           texture2d<half, access::write>  ycc [[ texture(2) ]], // Luma / Chroma
                           constant Uniforms               &u  [[ buffer(0)  ]],
                           sampler                         sam [[ sampler(0) ]],
                           uint2                           gid [[ thread_position_in_grid ]])
    {
        // Get size of output textures
        const Coord2 rect = float2(lin.get_width(), lin.get_height());

        // Normalize gid to 0..1 in rect
        Coord2 uv = (Coord2(gid) + 0.5) / rect;

        // Read pixel
        Color3 rgb = pow(Color3(src.sample(sam, uv).rgb), Color3(u.GAMMA_INPUT));
        lin.write(Color4(rgb, 1.0), gid);
        
        // Split components
        Color3 split = u.PAL == 1 ? RGB2YUV(rgb) : RGB2YIQ(rgb);
        ycc.write(Color4(split, 1.0), gid);
    }

    kernel void composite(texture2d<half, access::sample> ycc [[ texture(0) ]], // Luma / Chroma (in)
                          texture2d<half, access::write>  out [[ texture(1) ]], // Luma / Chroma (out)
                          texture2d<half, access::write>  bri [[ texture(2) ]], // Brightness (blooming)
                          constant Uniforms               &u  [[ buffer(0)  ]],
                          sampler                         sam [[ sampler(0) ]],
                          uint2                           gid [[ thread_position_in_grid ]])
    {
        uint W = out.get_width();
        uint H = out.get_height();
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
        
        out.write(color, gid);

        //
        // Brightness pass
        //

        if (u.BLOOM_ENABLE) {

            // Compute luminance
            Color Y = dot(rgb, Color3(0.299, 0.587, 0.114));

            // Keep only if brighter than threshold
            half3 mask = half3(smoothstep(u.BLOOM_THRESHOLD, u.BLOOM_THRESHOLD + 0.1, float3(Y)));

            // Scale the bright part
            bri.write(half4(color.rgb * mask * u.BLOOM_INTENSITY, 1.0), gid);
        }
    }

    inline half4 scanline(half4 x, float weight) {
        
        return pow(x, pow(mix(0.8, 1.2, weight), 8));
    }
    
    kernel void crt(texture2d<half, access::sample> rgb [[ texture(0) ]], // RGB
                    texture2d<half, access::sample> ycc [[ texture(1) ]], // Luma / Chroma
                    texture2d<half, access::sample> dom [[ texture(2) ]], // Dot Mask
                    texture2d<half, access::sample> blm [[ texture(3) ]], // Bloom
                    texture2d<half, access::write>  out [[ texture(4) ]],
                    constant Uniforms               &u  [[ buffer(0)  ]],
                    sampler                         sam [[ sampler(0) ]],
                    uint2                           gid [[ thread_position_in_grid ]])
    {
        // Normalize gid to 0..1 in output texture
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(out.get_width(), out.get_height());

        // Read source pixel
        Color4 color = rgb.sample(sam, uv);
                
        // Apply the scanline effect
        if (u.SCANLINES_ENABLE) {
            
            uint line = gid.y % uint(u.SCANLINE_DISTANCE);
            
            Color4 blurred = rgb.sample(sam, uv, level(u.SCANLINE_SHARPNESS));
            color = mix(color, blurred, u.SCANLINE_BLOOM);
            
            if (line == 0) {
                color = scanline(color, u.SCANLINE_WEIGHT1);
            } else if (line == 1) {
                color = scanline(color, u.SCANLINE_WEIGHT2);
            } else if (line == 2) {
                color = scanline(color, u.SCANLINE_WEIGHT3);
            } else if (line == 3) {
                color = scanline(color, u.SCANLINE_WEIGHT4);
            } else if (line == 4) {
                color = scanline(color, u.SCANLINE_WEIGHT5);
            } else if (line == 5) {
                color = scanline(color, u.SCANLINE_WEIGHT6);
            } else if (line == 6) {
                color = scanline(color, u.SCANLINE_WEIGHT7);
            } else if (line == 7) {
                color = scanline(color, u.SCANLINE_WEIGHT8);
            }
        }

        // Apply the dot mask effect
        if (u.DOTMASK_ENABLE) {
            
            Color4 mask = dom.sample(sam, uv, level(u.DOTMASK_BLUR));
            Color4 gain = min(color, 1 - color) * mask;
            Color4 loose = min(color, 1 - color) * (1 - mask);
            color += u.DOTMASK_GAIN * gain + u.DOTMASK_LOOSE * loose;
        }

        // Apply the bloom effect
        if (u.BLOOM_ENABLE) {

            Color4 bloom = blm.sample(sam, uv);
            color = saturate(color + bloom);
        }

        
        out.write(pow(color, Color4(1.0 / u.GAMMA_OUTPUT)), gid);
        return;
    }

    //
    // Debug kernel
    //
    
    inline int debugPixelType(uint2 gid, uint2 size, constant Uniforms &u) {
        
        int cutoff = int(u.DEBUG_SLICE * size.x);
        int coord = gid.x;
        
        return coord < cutoff ? -1 : coord > cutoff ? 1 : 0;
    }
     
    inline Color4 sampleDebugTexture(int source,
                                     Coord2 uv,
                                     texture2d<half, access::sample> src [[ texture(0) ]],
                                     texture2d<half, access::sample> ycc [[ texture(1) ]],
                                     texture2d<half, access::sample> dom [[ texture(2) ]],
                                     texture2d<half, access::sample> blm [[ texture(3) ]],
                                     texture2d<half, access::sample> dbg [[ texture(4) ]],
                                     constant Uniforms               &u  [[ buffer(0)  ]],
                                     sampler                         sam [[ sampler(0) ]],
                                     uint2                           gid [[ thread_position_in_grid ]])
    {
        Color4 color;

        switch (source) {

            case 0:
                
                color = src.sample(sam, uv);
                break;

            case 1:
                
                color = dbg.sample(sam, uv);
                break;

            case 2:
                
                color = ycc.sample(sam, uv, level(u.DEBUG_MIPMAP));
                color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                break;
                
            case 3:
                
                color = ycc.sample(sam, uv, level(u.DEBUG_MIPMAP)).xxxw;
                break;
                
            case 4:
                
                color = ycc.sample(sam, uv, level(u.DEBUG_MIPMAP));
                color = Color4(1.0, color.y, 0.0, color.w);
                color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                break;
                
            case 5:
                
                color = ycc.sample(sam, uv, level(u.DEBUG_MIPMAP));
                color = Color4(1.0, 0.0, color.z, color.w);
                color = Color4(u.PAL ? YUV2RGB(color.xyz) : YIQ2RGB(color.xyz), 1.0);
                break;
                
            case 6:
                color = dom.sample(sam, uv, level(u.DEBUG_MIPMAP));
                break;
                                
            default:
                color = blm.sample(sam, uv);
                break;
        }

        return color;
    }
    
    inline Color4 mixDebugPixel(Color4 color1, Color4 color2, int mode) {
        
        switch (mode) {
                
            case 0:  return color1;
            case 1:  return color2;
            default: return 0.5 + 0.5 * (color1 - color2); // abs(color1 - color2);
        }
    }
    
    kernel void debug(texture2d<half, access::sample> src [[ texture(0) ]], // Original
                      texture2d<half, access::sample> ycc [[ texture(1) ]], // Luma / Chroma
                      texture2d<half, access::sample> dom [[ texture(2) ]], // Dot Mask
                      texture2d<half, access::sample> blm [[ texture(3) ]], // Bloom
                      texture2d<half, access::sample> dbg [[ texture(4) ]], // Final (read)
                      texture2d<half, access::write>  fin [[ texture(5) ]], // Final (write)
                      constant Uniforms               &u  [[ buffer(0)  ]],
                      sampler                         sam [[ sampler(0) ]],
                      uint2                           gid [[ thread_position_in_grid ]])
    {
        // Normalize gid to 0..1 in output texture
        uint2 size = uint2(fin.get_width(), fin.get_height());
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(size);
                
        // Sample the selected texures
        Color4 color1 = sampleDebugTexture(u.DEBUG_TEXTURE1,
                                         uv, src, ycc, dom, blm, dbg, u, sam, gid);
        Color4 color2 = sampleDebugTexture(u.DEBUG_TEXTURE2,
                                         uv, src, ycc, dom, blm, dbg, u, sam, gid);

        // Compute the pixel to display
        switch (debugPixelType(gid, size, u)) {
                
            case -1: fin.write(mixDebugPixel(color1, color2, u.DEBUG_LEFT), gid); break;
            case  1: fin.write(mixDebugPixel(color1, color2, u.DEBUG_RIGHT), gid); break;
            default: fin.write(Color4(1.0,1.0,1.0,1.0), gid);
        }
    }
}
