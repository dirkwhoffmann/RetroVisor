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

        // General
        uint  PAL;
        float GAMMA_INPUT;
        float GAMMA_OUTPUT;
        float INPUT_TEX_SCALE;
        float OUTPUT_TEX_SCALE;
        uint  RESAMPLE_FILTER;
        uint  BLUR_FILTER;
        
        // Composite video effects
        uint  CV_ENABLE;
        float CV_CONTRAST;
        float CV_BRIGHTNESS;
        float CV_SATURATION;
        float CV_TINT;
        float CV_BRIGHT_BOOST;
        float CV_BRIGHT_BOOST_POST;
        float CV_CHROMA_BOOST;
        float CV_CHROMA_BLUR;

        // Bloom effect
        uint  BLOOM_ENABLE;
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
        float DOTMASK_LOSS;

        // Scanlines
        uint  SCANLINES_ENABLE;
        uint  SCANLINE_DISTANCE;
        float SCANLINE_SHARPNESS;
        float SCANLINE_BLUR;
        float SCANLINE_BLOOM;
        float SCANLINE_STRENGTH;
        float SCANLINE_GAIN;
        float SCANLINE_LOSS;
        float SCANLINE_WEIGHT[8];
        
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
    // Little helpers
    //
    
    inline Color4 sampleRGB(texture2d<half> tex, sampler sam, float2 uv, float mipLevel = 0) {
        
        return tex.sample(sam, uv, level(mipLevel));
    }

    inline Color4 sampleYCC(texture2d<half> tex, sampler sam, float2 uv, float mipLevel = 0) {
        
        return tex.sample(sam, uv, level(mipLevel)) + Color4(0.0, -0.5, -0.5, 0.0);
    }
    
    //
    // SPlit filter (RGB to YUV or YIQ)
    //
    
    kernel void split(texture2d<half, access::sample> src [[ texture(0) ]], // RGB
                      texture2d<half, access::write>  ycc [[ texture(1) ]], // Luma / Chroma
                      texture2d<half, access::write>  yc0 [[ texture(2) ]], // Luma
                      texture2d<half, access::write>  yc1 [[ texture(3) ]], // First Chroma
                      texture2d<half, access::write>  yc2 [[ texture(4) ]], // Second Chroma
                      texture2d<half, access::write>  bri [[ texture(5) ]], // Brightness texture
                      constant Uniforms               &u  [[ buffer(0)  ]],
                      sampler                         sam [[ sampler(0) ]],
                      uint2                           gid [[ thread_position_in_grid ]])
    {
        // Normalize gid to [0..1]
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(ycc.get_width(), ycc.get_height());

        // Read pixel
        Color3 rgb = Color3(src.sample(sam, uv).rgb);

        // Apply gamma correction
        rgb = pow(rgb, Color3(u.GAMMA_INPUT));
        
        // Split components
        Color3 split = RGB2YCC(rgb, u.PAL);
        
        // Boost brightness (DEPRECATED)
        // split.x *= u.BRIGHT_BOOST;
  
        
        if (u.BLOOM_ENABLE) {
            
            // Filter out all texels below the threshold
            Color threshold = u.BLOOM_THRESHOLD;
            // Color mask = smoothstep(threshold, threshold + 0.1h, split.x);
            Color mask = smoothstep(threshold, 1.0h, split.x);

            // Scale the bright part
            Color intensity = u.BLOOM_INTENSITY;
            bri.write(split.x * mask * 2.0 * intensity, gid);
            // bri.write(pow(split.x, 1 + 10 * intensity), gid);
        }
        
        if (u.CV_ENABLE) {
            
            // Prepare the input textures for the composite filter
            yc0.write(split.x, gid);
            yc1.write(split.y + 0.5, gid);
            yc2.write(split.z + 0.5, gid);

        } else {
            
            // Assemble the final ycc texture, so we can bypass the composite filter
            ycc.write(Color4(split.x, split.y + 0.5, split.z + 0.5, 1.0), gid);
        }
    }

    //
    // Composite filter (merge seperate channels into common YCC texture)
    //
    
    kernel void composite(texture2d<half, access::sample> ch0 [[ texture(0) ]], // Luma
                          texture2d<half, access::sample> ch1 [[ texture(1) ]], // Chroma
                          texture2d<half, access::sample> ch2 [[ texture(2) ]], // Chroma
                          texture2d<half, access::write>  ycc [[ texture(3) ]],
                          constant Uniforms               &u  [[ buffer(0)  ]],
                          sampler                         sam [[ sampler(0) ]],
                          uint2                           gid [[ thread_position_in_grid ]])
    {
        Color y  = ch0.read(gid).x;
        Color c1 = ch1.read(gid).x - 0.5;
        Color c2 = ch2.read(gid).x - 0.5;
        
        // Adjust contrast and brightness (uniforms in [0..1])
        y = ((y - 0.5) * (0.5 + u.CV_CONTRAST) + 0.5) * (u.CV_BRIGHTNESS + 0.5);

        // Adjust saturation and tint (uniforms in [0..1])
        float cosA = cos(u.CV_TINT), sinA = sin(u.CV_TINT);
        float2 cc = float2(c1 * cosA - c2 * sinA, c1 * sinA + c2 * cosA) * (0.5 + u.CV_SATURATION);
        
        ycc.write(Color4(y, cc.x + 0.5, cc.y + 0.5, 1.0), gid);
    }
    
    //
    // Main CRT shader
    //
    
    kernel void crt(texture2d<half, access::sample> ycc [[ texture(0) ]], // Luma / Chroma
                    texture2d<half, access::sample> bl0 [[ texture(1) ]], // Bloom (Luma)
                    texture2d<half, access::sample> bl1 [[ texture(2) ]], // Bloom (Chroma 1)
                    texture2d<half, access::sample> bl2 [[ texture(3) ]], // Bloom (Chroma 2)
                    texture2d<half, access::sample> dom [[ texture(4) ]], // Dot Mask
                    texture2d<half, access::write>  out [[ texture(5) ]],
                    constant Uniforms               &u  [[ buffer(0)  ]],
                    sampler                         sam [[ sampler(0) ]],
                    uint2                           gid [[ thread_position_in_grid ]])
    {
        // Normalize gid to [0..1]
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(out.get_width(), out.get_height());

        // Read source pixel
        Color4 yccColor = sampleYCC(ycc, sam, uv);

        // Apply bloom effect
        if (u.BLOOM_ENABLE) {

            Color bloom = bl0.sample(sam, uv).x;
            yccColor.x = saturate(yccColor.x + bloom);
        }
        
        // Apply the scanline effect
        if (u.SCANLINES_ENABLE) {
            
            uint line = gid.y % (2 * u.SCANLINE_DISTANCE);
            if (line >= u.SCANLINE_DISTANCE) line = 2 * u.SCANLINE_DISTANCE - 1 - line;
            
            Color4 blurred = sampleYCC(ycc, sam, uv, u.SCANLINE_BLUR);
            yccColor = mix(yccColor, blurred, u.SCANLINE_BLOOM);

            float w = u.SCANLINE_WEIGHT[line];
            yccColor.x = remap(float(yccColor.x), 1.0 - w, u.SCANLINE_GAIN, u.SCANLINE_LOSS);
            // color = remap(color, w, u.SCANLINE_SHARPNESS);
            // color = scanline(color, u.SCANLINE_WEIGHT[line]);

        }
        Color4 color = YCC2RGB(yccColor, u.PAL);

        // Apply the dot mask effect
        if (u.DOTMASK_ENABLE) {
            
            Color4 mask = sampleRGB(dom, sam, uv, u.DOTMASK_BLUR);
            Color4 gain = min(color, 1 - color) * mask;
            Color4 loose = min(color, 1 - color) * (1 - mask);
            color += u.DOTMASK_GAIN * gain + u.DOTMASK_LOSS * loose;
        }

        // Apply the bloom effect
        
        /*
        if (u.BLOOM_ENABLE) {

            Color4 bloom = blm.sample(sam, uv);
            color = saturate(color + YCC2RGB(bloom, u.PAL));
        }
        */
        
        // Boost brightness and correct gamma
        out.write(pow(color * u.CV_BRIGHT_BOOST_POST, Color4(1.0 / u.GAMMA_OUTPUT)), gid);
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
                                     texture2d<half, access::sample> fin [[ texture(1) ]],
                                     texture2d<half, access::sample> ycc [[ texture(2) ]],
                                     texture2d<half, access::sample> yc0 [[ texture(3) ]],
                                     texture2d<half, access::sample> yc1 [[ texture(4) ]],
                                     texture2d<half, access::sample> yc2 [[ texture(5) ]],
                                     texture2d<half, access::sample> bl0 [[ texture(6) ]],
                                     texture2d<half, access::sample> bl1 [[ texture(7) ]],
                                     texture2d<half, access::sample> bl2 [[ texture(8) ]],
                                     texture2d<half, access::sample> bri [[ texture(9) ]],
                                     texture2d<half, access::sample> dom [[ texture(10)]],
                                     constant Uniforms               &u  [[ buffer(0)  ]],
                                     sampler                         sam [[ sampler(0) ]],
                                     uint2                           gid [[ thread_position_in_grid ]])
    {
        switch (source) {

            case 0:  return sampleRGB(src, sam, uv);
            case 1:  return sampleRGB(fin, sam, uv);
            case 2:  return YCC2RGB(sampleYCC(ycc, sam, uv, u.DEBUG_MIPMAP), u.PAL);
            case 3:  return Color4(sampleYCC(yc0, sam, uv).xxx, 1.0);
            case 4:  return Color4(sampleYCC(yc1, sam, uv).xxx, 1.0);
            case 5:  return Color4(sampleYCC(yc2, sam, uv).xxx, 1.0);
            case 6:  return Color4(sampleYCC(bl0, sam, uv).xxx, 1.0);
            case 7:  return Color4(sampleYCC(bl1, sam, uv).xxx, 1.0);
            case 8:  return Color4(sampleYCC(bl2, sam, uv).xxx, 1.0);
            case 9:  return Color4(sampleYCC(bri, sam, uv).xxx, 1.0);
            case 10: return sampleRGB(dom, sam, uv, u.DEBUG_MIPMAP);
                                
            default:
                return Color4(0.0, 0.0, 0.0, 1.0);
        }
    }
    
    inline Color4 mixDebugPixel(Color4 color1, Color4 color2, int mode) {
        
        switch (mode) {
                
            case 0:  return color1;
            case 1:  return color2;
            default: return 0.5 + 0.5 * (color1 - color2); // abs(color1 - color2);
        }
    }
    
    kernel void debug(texture2d<half, access::sample> src [[ texture(0) ]],
                      texture2d<half, access::sample> fin [[ texture(1) ]],
                      texture2d<half, access::sample> ycc [[ texture(2) ]],
                      texture2d<half, access::sample> yc0 [[ texture(3) ]],
                      texture2d<half, access::sample> yc1 [[ texture(4) ]],
                      texture2d<half, access::sample> yc2 [[ texture(5) ]],
                      texture2d<half, access::sample> bri [[ texture(6) ]],
                      texture2d<half, access::sample> bl0 [[ texture(7) ]],
                      texture2d<half, access::sample> bl1 [[ texture(8) ]],
                      texture2d<half, access::sample> bl2 [[ texture(9) ]],
                      texture2d<half, access::sample> dom [[ texture(10)]],
                      texture2d<half, access::write>  out [[ texture(11)]],
                      constant Uniforms               &u  [[ buffer(0)  ]],
                      sampler                         sam [[ sampler(0) ]],
                      uint2                           gid [[ thread_position_in_grid ]])
    {
        // Normalize gid to 0..1 in output texture
        uint2 size = uint2(out.get_width(), out.get_height());
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(size);
                
        // Sample the selected texures
        Color4 color1 = sampleDebugTexture(u.DEBUG_TEXTURE1, uv,
                                           src, fin, ycc, yc0, yc1, yc2, bri, bl0, bl1, bl2, dom,
                                           u, sam, gid);
        Color4 color2 = sampleDebugTexture(u.DEBUG_TEXTURE2, uv,
                                           src, fin, ycc, yc0, yc1, yc2, bri, bl0, bl1, bl2, dom,
                                           u, sam, gid);

        // Compute the pixel to display
        switch (debugPixelType(gid, size, u)) {
                
            case -1: out.write(mixDebugPixel(color1, color2, u.DEBUG_LEFT), gid); break;
            case  1: out.write(mixDebugPixel(color1, color2, u.DEBUG_RIGHT), gid); break;
            default: out.write(Color4(1.0,1.0,1.0,1.0), gid);
        }
    }
}
