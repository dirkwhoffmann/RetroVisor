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
#include "MathToolbox.metal"
#include "ColorToolbox.metal"

using namespace metal;

//
// Welcome to Dirk's shader playground
//

namespace playground {
    
    typedef float   Coord;
    typedef float2  Coord2;
    typedef half    Color;
    typedef half3   Color3;
    typedef half4   Color4;
    
    struct PlaygroundUniforms {

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

        uint  SCANLINE_ENABLE;
        float SCANLINE_BRIGHTNESS;
        float SCANLINE_WEIGHT1;
        float SCANLINE_WEIGHT2;
        float SCANLINE_WEIGHT3;
        float SCANLINE_WEIGHT4;
        float SCANLINE_WEIGHT5;
        float SCANLINE_WEIGHT6;
        float SCANLINE_WEIGHT7;
        float SCANLINE_WEIGHT8;

        // Shadow mask
        uint  SHADOW_ENABLE;
        float BRIGHTNESS;
        float GLOW;
        float SHADOW_GRID_WIDTH;
        float SHADOW_GRID_HEIGHT;
        float SHADOW_DOT_WIDTH;
        float SHADOW_DOT_HEIGHT;
        float SHADOW_DOT_WEIGHT;
        float SHADOW_DOT_GLOW;
        float SHADOW_FEATHER;

        // Dot mask
        uint  DOTMASK_ENABLE;
        uint  DOTMASK;
        float DOTMASK_BRIGHTNESS;

        uint  DEBUG_ENABLE;
        uint  DEBUG_TEXTURE;
        float DEBUG_SLIDER;
    };

 
    //
    // RGB to YUV/YIQ converter
    //

    kernel void colorSpace(texture2d<half, access::sample> inTex     [[ texture(0) ]],
                           texture2d<half, access::write>  outTex    [[ texture(1) ]],
                           constant PlaygroundUniforms     &u        [[ buffer(0)  ]],
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

    kernel void shadowMask(texture2d<half, access::sample> input     [[ texture(0) ]],
                           texture2d<half, access::write>  output    [[ texture(1) ]],
                           constant PlaygroundUniforms     &u        [[ buffer(0)  ]],
                           sampler                         sam       [[ sampler(0) ]],
                           uint2                           gid       [[ thread_position_in_grid ]])
    {
        // uint2 size = uint2(output.get_width(), output.get_height());
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(output.get_width(), output.get_height());

        uint2 gridSize = uint2(int(u.SHADOW_GRID_WIDTH * u.OUTPUT_TEX_SCALE),
                               int(u.SHADOW_GRID_HEIGHT * u.OUTPUT_TEX_SCALE));


        // Sample original color
        Color4 srcColor = input.sample(sam, uv, level(3));

        // Get the luminance
        float luminance = srcColor.x;

        /*
        // Set up the dot lattice
        float2 cellSize = float2(u.SHADOW_GRID_WIDTH * u.OUTPUT_TEX_SCALE,
                                 u.SHADOW_GRID_HEIGHT * u.OUTPUT_TEX_SCALE);
        float2 pixelCoord = float2(gid);
        float2 gridCoord = floor(pixelCoord / cellSize);
        float2 gridCenter = (gridCoord + 0.5) * cellSize;
        */

        // Normalize gid relative to its grid cell
        float2 nrmgid = float2(gid % gridSize) / float2(gridSize.x - 1, gridSize.y - 1);

        // Center at (0,0)
        nrmgid -= float2(0.5, 0.5);

        // Limit the dot size
        nrmgid = nrmgid / float2(u.SHADOW_DOT_WIDTH, u.SHADOW_DOT_HEIGHT);

        // Modify dot size w.r.t. luminance
        // nrmgid = nrmgid / float2(1.0, 1.0 - (1.0 - luminance) * (1.0 - u.SHADOW_DOT_WEIGHT));
        // nrmgid = nrmgid / (1.0 + (1.0 - pow(luminance, u.SHADOW_DOT_GLOW)) * u.SHADOW_DOT_WEIGHT); // /
        nrmgid = nrmgid / (1.0 + (pow(luminance, 1 / (u.SHADOW_DOT_GLOW))) * u.SHADOW_DOT_WEIGHT); // / float2(1.0, smoothstep(0.0, 1.0 - u.SHADOW_DOT_WEIGHT, luminance));

        float dist = length(nrmgid);

        // Normalized distance to nearest dot center (in pixels)
        // float2 d = (pixelCoord - gridCenter) / cellSize;
        // float dist = length(d);

        // Compute radius based on luminance
        // float radius = mix(u.SHADOW_DOT_WEIGHT, u.SHADOW_DOT_WIDTH, pow(luminance, u.GLOW));
        float radius = dist;

        // --- Dot falloff ---
        // Smoothstep makes soft edges, bigger for bright pixels
        // float spot = smoothstep(radius, radius * 0.5, dist);
        float offset = 0; // luminance * u.SHADOW_DOT_WEIGHT;
        float offset2 = 0; // (1.0 - luminance) * u.SHADOW_DOT_WEIGHT;
        float spot = smoothstep(1.0 - offset2, offset, radius);

        // Scale final brightness by luminance
        Color3 finalColor = Color3(spot); //  srcColor * spot;

        // return float4(finalColor, 1.0);

        output.write(half4(finalColor, 1.0), gid);
    }

    struct DotMaskdUniforms {
        
        uint TYPE;
        uint CELL_WIDTH;
        uint CELL_HEIGHT;
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
        // uint2 gridSize = uint2(input.get_width(), input.get_height());
        // uint2 gridSize = uint2(u.CELL_WIDTH, u.CELL_HEIGHT);
        uint2 gridSize = uint2(float2(u.CELL_WIDTH, u.CELL_HEIGHT) * texSize);

        float2 uv = (float2(gid % gridSize) + 0.5) / float2(gridSize);

        half4 color = input.sample(sam, uv);

        /*
        color = Color4(0.0,0.0,0.0,1.0);
        if (gid.x % u.CELL_HEIGHT == 0) color = Color4(1.0,1.0,1.0,1.0);
        if (gid.y % u.CELL_HEIGHT == 0) color = Color4(1.0,1.0,1.0,1.0);
        */
        output.write(color, gid);
    }

    kernel void composite(texture2d<half, access::sample> ycc       [[ texture(0) ]],
                          texture2d<half, access::sample> dotMask   [[ texture(1) ]],
                          texture2d<half, access::write>  outTex    [[ texture(2) ]],
                          texture2d<half, access::write>  brightTex [[ texture(3) ]],
                          constant PlaygroundUniforms     &u        [[ buffer(0)  ]],
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
        Color3 combined = Color3(yccC.x, uOut, vOut);
        Color3 rgb = u.PAL ? YUV2RGB(combined) : YIQ2RGB(combined);

        // Write pixel
        // outTex.write(half4(half3(rgb), 1.0), gid);

        //
        // Dotmask
        //

        half4 color = half4(half3(rgb), 1.0);

        /*
        if (u.DOTMASK_ENABLE) {

            // Normalize gid to 0..1 in dotmask texture
            Coord2 dotuv = (Coord2(gid) + 0.5) / Coord2(dotMask.get_width(), dotMask.get_height());

            // half4 dotColor = dotMask.read(gid);
            Color4 dotColor = dotMask.sample(sam, dotuv);
            Color4 gain = min(color, 1 - color) * dotColor;
            Color4 loose = min(color, 1 - color) * 0.5 * (1 - dotColor);
            color += gain - loose;
        }
        */
        
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

        return pow(x, exp(4*(weight - 0.5)));
    }

    kernel void crt(texture2d<half, access::sample> inTex     [[ texture(0) ]],
                    texture2d<half, access::sample> shadow    [[ texture(1) ]],
                    texture2d<half, access::sample> dotMask   [[ texture(2) ]],
                    texture2d<half, access::sample> bloomTex  [[ texture(3) ]],
                    texture2d<half, access::write>  outTex    [[ texture(4) ]],
                    constant PlaygroundUniforms     &u        [[ buffer(0)  ]],
                    sampler                         sam       [[ sampler(0) ]],
                    uint2                           gid       [[ thread_position_in_grid ]])
    {
        // float2 size = float2(outTex.get_width(), outTex.get_height());

        // Normalize gid to 0..1 in output texture
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(outTex.get_width(), outTex.get_height());

        // Read image
        half4 color = inTex.sample(sam, uv);

        // Apply shadow mask effect
        if (u.SHADOW_ENABLE) {

            color *= shadow.sample(sam, uv);
        }

        if (u.SCANLINE_ENABLE) {
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
        }

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
            // outTex.write(color, gid);
        }

        outTex.write(color, gid);
        return;

        /*
         // Compose RGB value
         half3 ycc = inTex.sample(sam, uv).xyz;
         // half3 rgb = half3(u.PAL ? YUV2RGB(float3(ycc)) : YIQ2RGB(float3(ycc)));
         half3 rgb = ycc;

         outTex.write(half4(rgb, 1.0), gid);
         return;
         */

        //
        // Experimental...
        //

        /*
         // half4 color = inTex.sample(sam, uv);

         // Find the dot cell we are in
         uint2 maskSpacing = uint2(uint(u.SHADOW_GRID_WIDTH), uint(u.SHADOW_GRID_HEIGHT));

         // uint2 cell = gid / maskSpacing;
         float2 center = float2(uint2(gid / maskSpacing) * maskSpacing) + float2(maskSpacing) * 0.5;
         float2 centerL = center - float2(maskSpacing.x, 0.0);
         float2 centerR = center + float2(maskSpacing.x, 0.0);

         // Get the center weights
         half3 weight = half3(inTex.sample(sam, center / size));
         half3 weightL = half3(inTex.sample(sam, centerL / size));
         half3 weightR = half3(inTex.sample(sam, centerR / size));

         // weight = weight; // 0.25 * weightL + 0.5 * weight + 0.25 * weightR;

         // Scale dot size based on weight
         float2 minDotSize = float2(u.SHADOW_DOT_WEIGHT, u.MIN_DOT_HEIGHT);
         float2 maxDotSize = float2(u.SHADOW_DOT_WIDTH, u.SHADOW_DOT_HEIGHT);

         float2 scaledRDotSize = mix(minDotSize, maxDotSize, weight.r);
         float2 scaledRDotSizeL = mix(minDotSize, maxDotSize, weightL.r);
         float2 scaledRDotSizeR = mix(minDotSize, maxDotSize, weightR.r);

         float2 scaledGDotSize = mix(minDotSize, maxDotSize, weight.g);
         float2 scaledGDotSizeL = mix(minDotSize, maxDotSize, weightL.g);
         float2 scaledGDotSizeR = mix(minDotSize, maxDotSize, weightR.g);

         float2 scaledBDotSize = mix(minDotSize, maxDotSize, weight.b);
         float2 scaledBDotSizeL = mix(minDotSize, maxDotSize, weightL.b);
         float2 scaledBDotSizeR = mix(minDotSize, maxDotSize, weightR.b);

         // Compute mask contributions
         float m0r = shapeMask(float2(gid) - center, scaledRDotSize, u);
         float mLr = shapeMask(float2(gid) - centerL, scaledRDotSizeL, u);
         float mRr = shapeMask(float2(gid) - centerR, scaledRDotSizeR, u);

         float m0g = shapeMask(float2(gid) - center, scaledGDotSize, u);
         float mLg = shapeMask(float2(gid) - centerL, scaledGDotSizeL, u);
         float mRg = shapeMask(float2(gid) - centerR, scaledGDotSizeR, u);

         float m0b = shapeMask(float2(gid) - center, scaledBDotSize, u);
         float mLb = shapeMask(float2(gid) - centerL, scaledBDotSizeL, u);
         float mRb = shapeMask(float2(gid) - centerR, scaledBDotSizeR, u);

         float3 m0 = float3(m0r, m0g, m0b);
         float3 mL = float3(mLr, mLg, mLb);
         float3 mR = float3(mRr, mRg, mRb);

         // Combine with horizontal glow (soft blending)
         // float glow = m0 + exp(-length(relLeft) / u.GLOW) * mL + exp(-length(relRight) / u.GLOW) * mR;
         float3 intensity = saturate(max(m0, m0 + mL + mR));

         // Modulate final glow by input color
         half3 result = u.BRIGHTNESS * pow(half3(intensity), 4.01 - 2 * u.GLOW) * inTex.sample(sam, uv).rgb; // half3(intensity);

         result.g = 0;
         result.b = 0;
         // Output (for now just grayscale, later modulate with input image color & size)
         outTex.write(half4(result, 1.0), gid);
         */
    }

    kernel void debug(texture2d<half, access::sample> ycc       [[ texture(0) ]],
                      texture2d<half, access::sample> shadow    [[ texture(1) ]],
                      texture2d<half, access::sample> dotMask   [[ texture(2) ]],
                      texture2d<half, access::sample> bloomTex  [[ texture(3) ]],
                      texture2d<half, access::write>  final     [[ texture(4) ]],
                      constant PlaygroundUniforms     &u        [[ buffer(0)  ]],
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
                    
                case 9:

                    color = shadow.sample(sam, uv);
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
