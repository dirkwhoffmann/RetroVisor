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
        float DOTMASK_WIDTH;
        float DOTMASK_SHIFT;
        float DOTMASK_WEIGHT;
        float DOTMASK_BRIGHTESS;

        // Scanlines
        uint  SCANLINES_ENABLE;
        float SCANLINE_DISTANCE;
        float SCANLINE_WEIGHT;
        float SCANLINE_BRIGHTNESS;
        
        // Debugging
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

    inline Color3 RGB2HSV(Color3 c) {
        
        Color4 K = Color4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
        Color4 p = (c.g < c.b) ? Color4(c.bg, K.wz) : Color4(c.gb, K.xy);
        Color4 q = (c.r < p.x) ? Color4(p.xyw, c.r) : Color4(c.r, p.yzx);

        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;

        float h = abs(q.z + (q.w - q.y) / (6.0 * d + e));
        float s = d / (q.x + e);
        float v = q.x;

        return Color3(h, s, v);
    }
    
    Color3 HSV2RGB(Color3 c) {
        
        Color4 K = Color4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
        Color3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }

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

    // x: phase in radians (0..2π for one period)
    // k: smoothness/spikiness (>0, higher = sharper spike)
    // width: fraction of the period occupied by the spike (0..1)
    float spikeTanhWidth(float x, float k, float width) {
        // normalize phase to [0,1)
        float p = fmod(x, 2.0f * M_PI) / (2.0f * M_PI);

        // remap phase so spike is centered at 0.5
        float d = (p - 0.5) / (0.5 * width); // normalized distance from spike center
        d = clamp(d, -1.0, 1.0);

        // apply tanh shaping
        float t = tanh(k * (1.0 - abs(d))); // 1-|d| gives peak at center, falls off to edges
        t /= tanh(k);                        // normalize to 0..1

        return t; // already 0..1
    }
    
    float dotMaskWeight(uint2 gid, float2 shift, constant Uniforms &u) {
        
        // Normalize gid relative to its grid cell
        uint2 gridSize = uint2(uint(u.DOTMASK_WIDTH), uint(u.DOTMASK_WIDTH));
        float2 sgid = float2(gid) + shift * u.DOTMASK_WIDTH;
        float2 nrmgid = fmod(sgid, float2(gridSize)) / float2(gridSize.x - 1, gridSize.y - 1);

        // Center at (0,0)
        nrmgid -= float2(0.5, 0.5);

        // Modulate the dot size
        // nrmgid = nrmgid / float2(u.SHADOW_DOT_WIDTH, u.SHADOW_DOT_HEIGHT);
        float dist2 = nrmgid.x * nrmgid.x; //  dot(nrmgid, nrmgid);
        
        // shift *= u.DOTMASK_WIDTH;
        // gid += (shift * u.DOTMASK_WIDTH);
        /*
        uint2 maskSpacing = uint2(uint(u.DOTMASK_WIDTH), uint(u.DOTMASK_WIDTH));
        float2 center = float2(uint2(gid / maskSpacing) * maskSpacing) + float2(maskSpacing) * 0.5;
        float2 nrmgid = float2(gid) / u.DOTMASK_WIDTH;
        float2 nrmcenter = center / u.DOTMASK_WIDTH;
        nrmcenter += shift;
        float2 diff = nrmgid - nrmcenter;
        // float2 diff = nrmgid - nrmcenter;
        float  dist2 = dot(diff, diff);      // squared distance
        */
        float  sigma = 3 * u.DOTMASK_WEIGHT;                  // tweak for spread
        float  weight = exp(-dist2 / (2.0 * sigma * sigma));
        // weight = length(diff);
        return weight;

        /*
        val = fmod(val, 2*M_PI);
        
        // float scale = pow(brightness, weight);
        if (val >= M_PI) {
            return brightness + (1 - brightness) * smoothstep(2*M_PI, M_PI + M_PI * weight, val);
        } else {
            return brightness + (1 - brightness) * smoothstep(0, M_PI - M_PI * weight, val);
        }
        */
    }
    
    kernel void dotMask(texture2d<half, access::sample> input     [[ texture(0) ]],
                        texture2d<half, access::write>  output    [[ texture(1) ]],
                        constant Uniforms               &u        [[ buffer(0)  ]],
                        sampler                         sam       [[ sampler(0) ]],
                        uint2                           gid       [[ thread_position_in_grid ]])
    {
        // float width = float(int(u.DOTMASK_WIDTH * u.OUTPUT_TEX_SCALE));
        // float sample = gid.x * 2 * M_PI / (u.DOTMASK_WIDTH * u.OUTPUT_TEX_SCALE);
        
        Color r = dotMaskWeight(gid, float2(0, 0), u);
        Color g = dotMaskWeight(gid, float2(u.DOTMASK_SHIFT, 0), u);
        Color b = dotMaskWeight(gid, float2(2 * u.DOTMASK_SHIFT, 0), u);
    
        /*
        Color r = spikeTanhWidth(sample, u.DOTMASK_WEIGHT, u.DOTMASK_WIDTH / 10.0);
        Color g = spikeTanhWidth(sample + u.DOTMASK_SHIFT, u.DOTMASK_WEIGHT, u.DOTMASK_WIDTH / 10.0);
        Color b = spikeTanhWidth(sample + 2.0 * u.DOTMASK_SHIFT, u.DOTMASK_WEIGHT, u.DOTMASK_WIDTH / 10.0);
        */
        Color4 color = Color4(r, g, b, 1.0);
        // Color4 color = Color4(r, 0.0, 0.0, 1.0);
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

    inline half3 scanlineWeight(uint2 pixel, uint height, float weight, float brightness, float bloom) {
        
        // Calculate distance to nearest scanline
        float dy = ((float(pixel.y % height) / float(height - 1)) - 0.5);
     
        // Calculate scanline weight
        float scanlineWeight = max(1.0 - dy * dy * 24 * weight, brightness);
        
        // Apply bloom effect an return
        half3 result = scanlineWeight * bloom;
        return result;
    }
    
    inline float wrap01(float x) { return x - floor(x); }           // like fract()
    inline float wrapSigned(float x) { return x - floor(x + 0.5f); } // to [-0.5, 0.5)

    // Shortest-arc interpolation on the hue circle (h in [0,1))
    inline float hue_lerp(float h0, float h1, float t)
    {
        float d = wrapSigned(h1 - h0);    // now d is in [-0.5, 0.5]
        return wrap01(h0 + t * d);
    }
    
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
        Color4 color = inTex.sample(sam, uv);
        
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

            Color4 mask = dotMask.sample(sam, uv); // dotMask.read(gid);
            
            // REMOVE ASAP
            outTex.write(mask, gid);
            return;
            
            if (u.DOTMASK_TYPE == 0) {
                
                // Multiply
                color = color * mask;
                // color *= u.DOTMASK_BRIGHTESS;
                
            } else if (u.DOTMASK_TYPE == 1) {
                
                // Blend
                color = mix(color, color * mask, u.DOTMASK_WEIGHT);
                
            } else {
                
                // Convert to HSV
                Color3 hsv = RGB2HSV(color.rgb);
                Color3 maskHSV = RGB2HSV(mask.rgb);

                // Mix the hues (circular interpolation is best)
                float mixAmount = u.DOTMASK_BRIGHTESS; // 0 = no effect, 1 = full mask hue
                hsv.x = hue_lerp(hsv.x, maskHSV.x, mixAmount); // hue
                // keep hsv.y (saturation) and hsv.z (value) unchanged

                // Convert back
                color = Color4(HSV2RGB(hsv), 1.0);
            }
            
            // Normalize gid to 0..1 in output texture
            // Coord2 uv = (Coord2(gid) + 0.5) / Coord2(outTex.get_width(), outTex.get_height());
        }

        // Apply bloom effect
        /*
        if (u.BLOOM_ENABLE) {

            Color4 bloom = bloomTex.sample(sam, uv);
            color = saturate(color + bloom);
        }
        */
        
        // Apply scanline effect (if emulation type matches)
        if (u.SCANLINES_ENABLE) {
            
            color.rgb *= scanlineWeight(gid,
                                        u.SCANLINE_DISTANCE,
                                        u.SCANLINE_WEIGHT,
                                        u.SCANLINE_BRIGHTNESS,
                                        1.0);
        }

        outTex.write(pow(color, Color4(1.0 / u.GAMMA_OUTPUT)), gid);
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
