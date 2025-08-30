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

typedef float   Coord;
typedef float2  Coord2;
typedef half    Color;
typedef half3   Color3;
typedef half4   Color4;

namespace dracula {

    constant constexpr float M_PI = 3.14159265358979323846264338327950288;

    struct Uniforms {

        float INPUT_TEX_SCALE;
        float OUTPUT_TEX_SCALE;
        uint  RESAMPLE_FILTER;

        // Chroma phase
        uint  PAL;
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
        float DOTMASK_WIDTH;
        float DOTMASK_SHIFT;
        float DOTMASK_WEIGHT;
        float DOTMASK_BRIGHTESS;

        uint  DEBUG_ENABLE;
        uint  DEBUG_TEXTURE;
        float DEBUG_SLIDER;
    };
    
    //
    // Color space helpers
    //

    inline float3 RGB2YIQ(float3 rgb) {

        // NTSC YIQ (BT.470)
        return float3(
                      dot(rgb, float3(0.299,  0.587,  0.114)),   // Y
                      dot(rgb, float3(0.596, -0.274, -0.322)),   // I
                      dot(rgb, float3(0.211, -0.523,  0.312))    // Q
                      );
    }

    inline half3 RGB2YIQ(half3 rgb) {

        return half3(RGB2YIQ(float3(rgb)));
    }

    inline float3 YIQ2RGB(float3 yiq) {

        float Y = yiq.x, I = yiq.y, Q = yiq.z;
        float3 rgb = float3(
                            Y + 0.956 * I + 0.621 * Q,
                            Y - 0.272 * I - 0.647 * Q,
                            Y - 1.106 * I + 1.703 * Q
                            );
        return clamp(rgb, 0.0, 1.0);
    }

    inline half3 YIQ2RGB(half3 yiq) {

        return half3(YIQ2RGB(float3(yiq)));
    }

    inline float3 RGB2YUV(float3 rgb) {

        // PAL-ish YUV (BT.601)
        return float3(
                      dot(rgb, float3(0.299,     0.587,    0.114)),   // Y
                      dot(rgb, float3(-0.14713, -0.28886,  0.436)),   // U
                      dot(rgb, float3(0.615,    -0.51499, -0.10001))  // V
                      );
    }

    inline half3 RGB2YUV(half3 rgb) {

        return half3(RGB2YUV(float3(rgb)));
    }

    inline float3 YUV2RGB(float3 yuv) {

        float Y = yuv.x, U = yuv.y, V = yuv.z;
        float3 rgb = float3(
                            Y + 1.13983 * V,
                            Y - 0.39465 * U - 0.58060 * V,
                            Y + 2.03211 * U
                            );
        return clamp(rgb, 0.0, 1.0);
    }

    inline half3 YUV2RGB(half3 yuv) {

        return half3(YUV2RGB(float3(yuv)));
    }

    //
    // RGB to YUV/YIQ converter
    //

    kernel void colorSpace(texture2d<half, access::sample> inTex     [[ texture(0) ]],
                           texture2d<half, access::write>  outTex    [[ texture(1) ]],
                           constant Uniforms               &u        [[ buffer(0)  ]],
                           sampler                         sam       [[ sampler(0) ]],
                           uint2                           gid       [[ thread_position_in_grid ]])
    {
        // Get size of output texture
        const Coord2 rect = float2(outTex.get_width(), outTex.get_height());

        // Normalize gid to 0..1 in rect
        Coord2 uv = (Coord2(gid) + 0.5) / rect;

        // Read pixel
        Color3 rgb = Color3(inTex.sample(sam, uv).rgb);

        // Split components
        Color3 ycc = u.PAL == 1 ? RGB2YUV(rgb) : RGB2YIQ(rgb);

        outTex.write(Color4(ycc, 1.0), gid);
    }

    /*
    inline float3 brightPass(float3 color, float luma, float threshold, float intensity) {

        // Keep only if brighter than threshold
        float mask = smoothstep(threshold, threshold + 0.1, luma);

        // Scale the bright part
        return color * mask * intensity;
    }
    */

    kernel void dotMask(texture2d<half, access::sample> input     [[ texture(0) ]],
                        texture2d<half, access::write>  output    [[ texture(1) ]],
                        constant Uniforms               &u        [[ buffer(0)  ]],
                        sampler                         sam       [[ sampler(0) ]],
                        uint2                           gid       [[ thread_position_in_grid ]])
    {
        // float width = float(int(u.DOTMASK_WIDTH * u.OUTPUT_TEX_SCALE));
        float sample = gid.x * 2 * M_PI / (u.DOTMASK_WIDTH * u.OUTPUT_TEX_SCALE);
        Color r = 0.5 + 0.5 * sin(sample);
        Color g = 0.5 + 0.5 * sin(sample + u.DOTMASK_SHIFT);
        Color b = 0.5 + 0.5 * sin(sample + 2 * u.DOTMASK_SHIFT);

        Color4 color = Color4(r, g, b, 1.0);
        
        output.write(color, gid);
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
        half4 yccC = ycc.read(gid);

        // Search the maximum chroma value in surrounding pixels
        int radius = u.CHROMA_RADIUS;
        half maxU = yccC.y, maxV = yccC.z;
        int maxDxU = 0, maxDxV = 0;

        for (int dx = -radius; dx <= radius; dx++) {

            if (dx == 0) continue;
            int x = clamp(int(gid.x) + dx, 0, int(W - 1));
            half4 sample = ycc.read(uint2(x, gid.y));

            if (sample.y > maxU) { maxU = sample.y; maxDxU = abs(dx); }
            if (sample.z > maxV) { maxV = sample.z; maxDxV = abs(dx); }
        }

        // Interpolation weights based on distance
        float distU = float(maxDxU) / float(max(1, radius));
        float distV = float(maxDxV) / float(max(1, radius));
        half uOut = mix(half(yccC.y), maxU, half(smoothstep(0.0, 1.0, 1.0 - distU)));
        half vOut = mix(half(yccC.z), maxV, half(smoothstep(0.0, 1.0, 1.0 - distV)));

        // Recombine with luma and convert back to RGB
        float3 combined = float3(yccC.x, uOut, vOut);
        float3 rgb = u.PAL ? YUV2RGB(combined) : YIQ2RGB(combined);

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
            float Y = dot(rgb, float3(0.299, 0.587, 0.114));

            // Keep only if brighter than threshold
            half3 mask = half3(smoothstep(u.BLOOM_THRESHOLD, u.BLOOM_THRESHOLD + 0.1, float3(Y)));

            // Scale the bright part
            brightTex.write(half4(color.rgb * mask * u.BLOOM_INTENSITY, 1.0), gid);
        }
    }

    /*
    half4 scanline(half4 x, float weight) {

        return pow(x, exp(4*(weight - 0.5)));
    }
    */

    kernel void crt(texture2d<half, access::sample> inTex     [[ texture(0) ]],
                    texture2d<half, access::sample> dotMask   [[ texture(1) ]],
                    texture2d<half, access::sample> bloomTex  [[ texture(2) ]],
                    texture2d<half, access::write>  outTex    [[ texture(3) ]],
                    constant Uniforms               &u        [[ buffer(0)  ]],
                    sampler                         sam       [[ sampler(0) ]],
                    uint2                           gid       [[ thread_position_in_grid ]])
    {
        // float2 size = float2(outTex.get_width(), outTex.get_height());

        // Normalize gid to 0..1 in output texture
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(outTex.get_width(), outTex.get_height());

        // Read dotmask
        Color4 color = dotMask.sample(sam, uv);

        /*
         uint line = gid.y % 4;

         if (line == 0) {
         color = scanline(color, u.SCANLINE_WEIGHT1);
         } else if (line == 1) {
         color = scanline(color, u.SCANLINE_WEIGHT2);
         } else if (line == 2) {
         color = scanline(color, u.SCANLINE_WEIGHT3);
         } else if (line == 3) {
         color = scanline(color, u.SCANLINE_WEIGHT4);
         }
         */

        /*
        // Apply dot mask effect
        if (u.DOTMASK_ENABLE) {

            // Normalize gid to 0..1 in output texture
            // Coord2 uv = (Coord2(gid) + 0.5) / Coord2(outTex.get_width(), outTex.get_height());
            
            Color4 dotColor = dotMask.read(gid);
            Color4 gain = min(color, 1 - color) * dotColor;
            Color4 loose = min(color, 1 - color) * 0.5 * (1 - dotColor);
            color += gain - loose;
        }

        // Apply bloom effect

        if (u.BLOOM_ENABLE) {

            Color4 bloom = bloomTex.sample(sam, uv);
            color = saturate(color + bloom);
        }
        */
        
        outTex.write(color, gid);
        return;
    }

    kernel void debug(texture2d<half, access::sample> ycc       [[ texture(0) ]],
                      texture2d<half, access::sample> dotMask   [[ texture(1) ]],
                      texture2d<half, access::sample> bloomTex  [[ texture(2) ]],
                      texture2d<half, access::write>  final     [[ texture(3) ]],
                      constant Uniforms               &u        [[ buffer(0)  ]],
                      sampler                         sam       [[ sampler(0) ]],
                      uint2                           gid       [[ thread_position_in_grid ]])
    {
        // Normalize gid to 0..1 in output texture
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(final.get_width(), final.get_height());

        if (gid.x >= u.DEBUG_SLIDER * final.get_width()) {

            Color4 color;

            switch(u.DEBUG_TEXTURE) {

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
                    
                default:

                    color = bloomTex.sample(sam, uv);
                    break;
            }
            
            final.write(color, gid);
            return;
        }
    }
}
