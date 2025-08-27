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
// Welcome to Dirk's shader playground
//

typedef float   Coord;
typedef float2  Coord2;
typedef half    Color;
typedef half3   Color3;
typedef half4   Color4;

namespace playground {

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

        // Sample original color
        Color4 srcColor = input.sample(sam, uv, level(3));

        // Get the luminance
        float luminance = srcColor.x;

        // Set up the dot lattice
        float2 cellSize = float2(u.SHADOW_GRID_WIDTH, u.SHADOW_GRID_HEIGHT);
        float2 pixelCoord = float2(gid);
        float2 gridCoord = floor(pixelCoord / cellSize);
        float2 gridCenter = (gridCoord + 0.5) * cellSize;

        // Normalized distance to nearest dot center (in pixels)
        float2 d = (pixelCoord - gridCenter) / cellSize;
        float dist = length(d);

        // --- Radius depends on luminance ---
        float radius = mix(u.SHADOW_MIN_DOT_WIDTH, 1.0, pow(luminance, u.GLOW));

        // --- Dot falloff ---
        // Smoothstep makes soft edges, bigger for bright pixels
        float spot = smoothstep(radius, radius * 0.5, dist);

        // Scale final brightness by luminance
        half3 finalColor = half3(spot); //  srcColor * spot;

        // return float4(finalColor, 1.0);

        output.write(half4(finalColor, 1.0), gid);
    }

    kernel void dotMask(texture2d<half, access::sample> input     [[ texture(0) ]],
                        texture2d<half, access::write>  output    [[ texture(1) ]],
                        sampler                         sam       [[ sampler(0) ]],
                        uint2                           gid       [[ thread_position_in_grid ]])
    {
        // uint2 inSize = (input.get_width(), input.get_height());
        uint2 gridSize = (input.get_width(), input.get_height());
        // uint2 mgid = gid % gridSize;

        float2 uv = (float2(gid % gridSize) + 0.5) / float2(gridSize);

        half4 color = input.sample(sam, uv);
        output.write(color, gid);
    }

    kernel void composite(texture2d<half, access::sample> ycc       [[ texture(0) ]],
                          texture2d<half, access::sample> dotMask   [[ texture(1) ]],
                          texture2d<half, access::write>  outTex    [[ texture(2) ]],
                          texture2d<half, access::write>  brightTex [[ texture(3) ]],
                          // constant Uniforms               &uniforms [[ buffer(0)  ]],
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
        float3 combined = float3(yccC.x, uOut, vOut);
        float3 rgb = u.PAL ? YUV2RGB(combined) : YIQ2RGB(combined);

        // Write pixel
        // outTex.write(half4(half3(rgb), 1.0), gid);

        //
        // Dotmask
        //

        half4 color = half4(half3(rgb), 1.0);

        if (u.DOTMASK_ENABLE) {

            half4 dotColor = dotMask.read(gid);
            half4 gain = min(color, 1 - color) * dotColor;
            half4 loose = min(color, 1 - color) * 0.5 * (1 - dotColor);
            color += gain - loose;
        }

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
        Coord2 uv = (Coord2(gid) + 0.5) / Coord2(outTex.get_width(), outTex.get_height());;

        // Read image
        half4 color = inTex.sample(sam, uv);

        // Read shadow mask
        half4 shadowColor = shadow.sample(sam, uv);

        color *= shadowColor;

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

        // Apply dot mask effect
        if (u.DOTMASK_ENABLE) {

            half4 dotColor = dotMask.read(gid);
            half4 gain = min(color, 1 - color) * dotColor;
            half4 loose = min(color, 1 - color) * 0.5 * (1 - dotColor);
            color += gain - loose;
        }

        // Apply bloom effect

        if (u.BLOOM_ENABLE) {

            half4 bloom = bloomTex.sample(sam, uv);
            color = saturate(color + bloom);
            outTex.write(color, gid);
            return;
        }

        // half4 bloom = bloomTex.sample(sam, uv);
        // outTex.write(bloom, gid);
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
         float2 minDotSize = float2(u.SHADOW_MIN_DOT_WIDTH, u.MIN_DOT_HEIGHT);
         float2 maxDotSize = float2(u.SHADOW_MAX_DOT_WIDTH, u.SHADOW_MAX_DOT_HEIGHT);

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
