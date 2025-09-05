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
        float BRIGHT_BOOST;
        float BRIGHT_BOOST_POST;
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
        uint  SCANLINE_DISTANCE;
        float SCANLINE_SHARPNESS;
        float SCANLINE_BLOOM;
        float SCANLINE_WEIGHT[8];
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
    // Color space converter (RGB to YUV or YIQ)
    //

    kernel void colorSpace(texture2d<half, access::sample> src [[ texture(0) ]], // RGB
                           // texture2d<half, access::write>  lin [[ texture(1) ]], // Linear RGB
                           texture2d<half, access::write>  ycc [[ texture(1) ]], // Luma / Chroma
                           constant Uniforms               &u  [[ buffer(0)  ]],
                           sampler                         sam [[ sampler(0) ]],
                           uint2                           gid [[ thread_position_in_grid ]])
    {
        // Get size of output textures
        const Coord2 rect = float2(ycc.get_width(), ycc.get_height());

        // Normalize gid to 0..1 in rect
        Coord2 uv = (Coord2(gid) + 0.5) / rect;

        // Read pixel
        Color3 rgb = Color3(src.sample(sam, uv).rgb);

        // Apply gamma correction
        rgb = pow(rgb, Color3(u.GAMMA_INPUT));
        
        // Split components
        Color3 split = u.PAL == 1 ? RGB2YUV(rgb) : RGB2YIQ(rgb);
        
        // Boost brightness
        split.x *= u.BRIGHT_BOOST;
        
        ycc.write(Color4(split, 1.0), gid);
    }

    //
    // Chroma effects
    //
    
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

        // Recombine with scaled luma and convert back to RGB
        Color3 combined = Color3(yccC.x, uOut, vOut);
        Color3 rgb = u.PAL ? YUV2RGB(combined) : YIQ2RGB(combined);

        Color4 color = Color4(rgb, 1.0);
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

    //
    // Main CRT shader
    //
    
    inline half4 scanline(half4 x, float weight) {
        
        return pow(x, pow(mix(1.2, 0.8, weight), 8));
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
            
            uint line = gid.y % (2 * u.SCANLINE_DISTANCE);
            if (line >= u.SCANLINE_DISTANCE) line = 2 * u.SCANLINE_DISTANCE - 1 - line;
            
            Color4 blurred = rgb.sample(sam, uv, level(u.SCANLINE_SHARPNESS));
            color = mix(color, blurred, u.SCANLINE_BLOOM);
            color = scanline(color, u.SCANLINE_WEIGHT[line]);
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
        
        // Boost brightness and correct gamma
        out.write(pow(color * u.BRIGHT_BOOST_POST, Color4(1.0 / u.GAMMA_OUTPUT)), gid);
    }

    //
    // Dotmask
    //
    
    kernel void dotMask(texture2d<half, access::sample> input     [[ texture(0) ]],
                        texture2d<half, access::write>  output    [[ texture(1) ]],
                        constant Uniforms               &u        [[ buffer(0)  ]],
                        sampler                         sam       [[ sampler(0) ]],
                        uint2                           gid       [[ thread_position_in_grid ]])
    {
        float2 texSize = float2(input.get_width(), input.get_height());
        uint2 gridSize = uint2(float2(u.DOTMASK_SIZE, u.DOTMASK_SIZE) * texSize);

        float2 uv = (float2(gid % gridSize) + 0.5) / float2(gridSize);

        half4 color = input.sample(sam, uv);
        output.write(color, gid);
    }

    //
    // Debug
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
