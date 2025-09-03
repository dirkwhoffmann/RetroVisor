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
    
    Color3 sigmoid(Color3 x, float k) {
        return 1.0 / (1.0 + exp(-k * (x - 0.5)));
    }

    float dotMaskWeight(uint2 gid, float2 shift, constant Uniforms &u) {
        
        // Setup the grid cell
        uint2 gridSize = uint2(uint(u.DOTMASK_WIDTH), uint(u.DOTMASK_WIDTH));

        // Shift gid
        gid += uint2(shift * u.DOTMASK_WIDTH);
        
        float2 sgid = float2(gid); //  + float2(uint2(shift * u.DOTMASK_WIDTH));

        // Normalize gid relative to its grid cell
        float2 nrmgid = fmod(sgid, float2(gridSize)) / float2(gridSize.x - 1, gridSize.y - 1);

        // Shift the center to (0,0)
        nrmgid -= float2(0.5, 0.5);

        // Modulate the dot size
        // nrmgid = nrmgid / float2(u.SHADOW_DOT_WIDTH, u.SHADOW_DOT_HEIGHT);

        // Compute distance to the center
        //float dist = max(1.0, (abs(nrmgid.x) - u.DOTMASK_BRIGHTNESS2));
        float length = max(0.0, (abs(nrmgid.x)));
        // float dist2 = length * length;
        
        // float weight = smoothstep(1.0, u.DOTMASK_BRIGHTNESS, dist);
        // weight = u.DOTMASK_BRIGHTNESS2 + (1 - u.DOTMASK_BRIGHTNESS2) * weight;
        // float weight = smoothstep(u.DOTMASK_WEIGHT + u.DOTMASK_WEIGHT2, u.DOTMASK_WEIGHT, length);
        float weight = smoothstep(u.DOTMASK_WEIGHT, 0.0, length);

            /*
        float sigma1 = u.DOTMASK_WEIGHT;                  // tweak for spread
        float sigma2 = u.DOTMASK_WEIGHT2;                  // tweak for spread

        float w1 = exp(-dist2 / (2.0 * sigma1 * sigma1)); // sharp core
        float w2 = exp(-dist2 / (2.0 * sigma2 * sigma2)); // wide halo
        float weight = u.DOTMASK_BRIGHTNESS * w1 + u.DOTMASK_BRIGHTNESS2 * w2; // a >> b
             */
        
        //weight = tanh(2*pow(cos(M_PI * length), u.DOTMASK_WEIGHT));
        //weight = u.DOTMASK_BRIGHTNESS + (1 - u.DOTMASK_BRIGHTNESS) * weight;
         
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
        
        // https://de.m.wikipedia.org/wiki/Farbvalenz
        /*
        Color3 R = Color3(0.64,0.33,0.03) / 0.64;
        Color3 G = Color3(0.30,0.60,0.10) / 0.60;
        Color3 B = Color3(0.15,0.06,0.79) / 0.79;
        */
        Color3 R = Color3(1.0,0.0,0.0);
        Color3 G = Color3(0.0,1.0,0.0);
        Color3 B = Color3(0.0,0.0,1.0);

        Color3 color = r * R + g * G + b * B;
        
        output.write(Color4(color, 1.0), gid);
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

    half4 scanline(half4 x, float weight) {
        
        return pow(x, pow(mix(0.8, 1.2, weight), 8));
    }

    /*
    inline half3 scanlineWeight(uint2 pixel, uint height, float weight, float brightness, float bloom) {
        
        // Calculate distance to nearest scanline
        float dy = ((float(pixel.y % height) / float(height - 1)) - 0.5);
     
        // Calculate scanline weight
        float scanlineWeight = max(1.0 - dy * dy * 24 * weight, brightness);
        
        // Apply bloom effect an return
        half3 result = scanlineWeight * bloom;
        return result;
    }
    */
    
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
            
            // uint column = gid.x % 4;
            // Color4 colcol = color;
            
            /*
            if (column == 0) {
                colcol = scanline(col, u.SCANLINE_WEIGHT1);
            } else if (column == 1) {
                colcol = scanline(col, u.SCANLINE_WEIGHT2);
            } else if (column == 2) {
                colcol = scanline(col, u.SCANLINE_WEIGHT3);
            } else if (column == 3) {
                colcol = scanline(col, u.SCANLINE_WEIGHT4);
            } else if (column == 4) {
                colcol = scanline(col, u.SCANLINE_WEIGHT5);
            } else if (column == 5) {
                colcol = scanline(col, u.SCANLINE_WEIGHT6);
            } else if (column == 6) {
                colcol = scanline(col, u.SCANLINE_WEIGHT7);
            } else if (column == 7) {
                colcol = scanline(col, u.SCANLINE_WEIGHT8);
            }
            */
            // if (column == 0) color *= 0.2;
            
            // color = mix(color, colcol, 0.5);
        }

        // Apply dot mask effect
        if (u.DOTMASK_ENABLE) {

            Color4 mask = dotMask.sample(sam, uv, level(u.DOTMASK_BLUR));
            // mask += dotMask.sample(sam, uv, level(u.DOTMASK_BLUR));
            // mask = Color4(sigmoid(mask.rgb, u.DOTMASK_BRIGHTNESS), 1.0);

            
            // REMOVE ASAP
            //outTex.write(mask, gid);
            // return;
            
            if (u.DOTMASK_TYPE == 0) {
                
                // Multiply
                color = color * (u.DOTMASK_MIX * mask + (1 - u.DOTMASK_MIX));
                // color *= u.DOTMASK_BRIGHTNESS;
                
            } else if (u.DOTMASK_TYPE == 1) {
                
                // Blend
                color = mix(color, mask, u.DOTMASK_MIX);
                
            } else if (u.DOTMASK_TYPE == 2) {
                
                Color4 gain = min(color, 1 - color) * mask;
                Color4 loose = min(color, 1 - color) * 0.5 * (1 - mask);
                color += u.DOTMASK_GAIN * gain - u.DOTMASK_LOOSE * loose;
     
            } else {
                
                // Convert to HSV
                Color3 hsv = RGB2HSV(color.rgb);
                Color3 maskHSV = RGB2HSV(mask.rgb);

                // Mix the hues (circular interpolation is best)
                float mixAmount = u.DOTMASK_MIX; // 0 = no effect, 1 = full mask hue
                hsv.x = hue_shift(hsv.x, maskHSV.x, mixAmount); // hue
                // keep hsv.y (saturation) and hsv.z (value) unchanged

                // Convert back
                color = Color4(HSV2RGB(hsv), 1.0);
                
                // color = Color4(HSV2RGB(Color3(maskHSV.x,1.0,1.0)), 1.0);
            }
            
            // Normalize gid to 0..1 in output texture
            // Coord2 uv = (Coord2(gid) + 0.5) / Coord2(outTex.get_width(), outTex.get_height());
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

                case 9:
                    color = dotMask.sample(sam, uv, level(u.DOTMASK_BLUR));
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
