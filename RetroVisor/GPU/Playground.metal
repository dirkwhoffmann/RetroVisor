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
// Welcome to Dirk's shader playground. Haters back off!
//

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

    inline float3 YIQ2RGB(float3 yiq) {

        float Y = yiq.x, I = yiq.y, Q = yiq.z;
        float3 rgb = float3(
            Y + 0.956 * I + 0.621 * Q,
            Y - 0.272 * I - 0.647 * Q,
            Y - 1.106 * I + 1.703 * Q
        );
        return clamp(rgb, 0.0, 1.0);
    }

    inline float3 RGB2YUV(float3 rgb) {

        // PAL-ish YUV (BT.601)
        return float3(
            dot(rgb, float3(0.299,     0.587,    0.114)),   // Y
            dot(rgb, float3(-0.14713, -0.28886,  0.436)),   // U
            dot(rgb, float3(0.615,    -0.51499, -0.10001))  // V
        );
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

    inline void gaussianWeights(const int halfWidth, float sigma, thread float *wOut)
    {
        // halfWidth=3 → 7 taps; halfWidth=4 → 9 taps, etc.
        float twoSigma2 = 2.0f * sigma * sigma;
        float sum = 0.0f;
        wOut[0] = 1.0f; // center
        for (int i = 1; i <= halfWidth; ++i) {
            float x = (float)i;
            float v = exp(- (x*x) / twoSigma2);
            wOut[i] = v;
            sum += 2.0f * v;
        }
        sum += 1.0f;
        float inv = 1.0f / sum;
        for (int i = 0; i <= halfWidth; ++i) wOut[i] *= inv;
    }

    //
    // Geometry helpers
    //

    // Fast Padé approximation for the Minkowski norm (|u|^n + |v|^n)^(1/n)
    inline float minkowski(float2 uv, float n)
    {
        float2 a = abs(uv);
        float m = max(a.x, a.y);
        if (m == 0.0f) return 0.0f;

        float l = min(a.x, a.y);
        float t = l / m;

        // s = t^n  (use fast log2/exp2; clamp to avoid log2(0))
        float s = fast::exp2(n * fast::log2(max(t, 1e-8f)));

        float invn = 1.0f / n;
        float A = 0.5f * (1.0f + invn); // (n+1)/(2n)
        float B = 0.5f * (1.0f - invn); // (n-1)/(2n)

        float g = (1.0f + A * s) / (1.0f + B * s);
        return m * g;
    }

    inline float shapeMask(float2 pos, float2 dotSize, constant PlaygroundUniforms& uniforms)
    {
        // Normalize position into [-1..1] range relative to dotSize
        float2 uv = pos / dotSize;

        // Compute the distance via the Minkowski norm (1 = Manhattan, 2 = Euclidean)
        float len = minkowski(uv, uniforms.SHAPE);

        // Blur the edge
        if (len > (1.0 - uniforms.FEATHER)) {
            return smoothstep(1.0 + uniforms.FEATHER, 1.0 - uniforms.FEATHER, len);
        } else {
            return 1.0;
        }
    }

    /*
    inline float2 remap(float2 uv, float2 rect, float4 texRect)
    {
        // Normalize gid to 0..1 in rect
        float2 uvOut = (float2(uv) + 0.5) / rect;

        // Remap to texRect in input texture
        return texRect.xy + uvOut * (texRect.zw - texRect.xy);
    }
    */

    // Remap to texRect in input texture
    inline float2 remap(float2 uv, float4 texRect)
    {
        return texRect.xy + uv * (texRect.zw - texRect.xy);
    }

    kernel void composite(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                          texture2d<half, access::write>  luma       [[ texture(1) ]],
                          texture2d<half, access::write>  chroma     [[ texture(2) ]],
                          constant Uniforms               &uniforms  [[ buffer(0)  ]],
                          constant PlaygroundUniforms     &u         [[ buffer(1)  ]],
                          sampler                         sam        [[ sampler(0) ]],
                          uint2                           gid        [[ thread_position_in_grid ]])
    {
        // if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

        // Get size of output texture
        const float2 rect = float2(luma.get_width(), luma.get_height());

        // Normalize gid to 0..1 in rect
        float2 uv = (float2(gid) + 0.5) / rect;

        // Remap to texRect in input texture
        uv = uniforms.texRect.xy + uv * (uniforms.texRect.zw - uniforms.texRect.xy);

        // Read pixel
        float3 rgb = float3(inTexture.sample(sam, uv).rgb);

        // Split components
        float3 ycc = u.PAL == 1 ? RGB2YUV(rgb) : RGB2YIQ(rgb);

        luma.write(half4(ycc.x, 0.0, 0.0, 0.0), gid);
        chroma.write(half4(ycc.y, ycc.z, 0.0, 0.0), gid);

        /*
        // Optional PAL vertical delay-line blend (emulates phase alternation cancel).
        // This softens vertical chroma detail (typical on PAL) while keeping luma sharp.
        if (isPAL && u.PAL_BLEND > 0.0f) {
            float2 vStep = float2(0.0f, texelSize.y);
            float3 rgbUp = float3(inTexture.sample(sam, remap(uv - vStep, uniforms.texRect)).rgb);
            float3 rgbDn = float3(inTexture.sample(sam, remap(uv + vStep, uniforms.texRect)).rgb);

            // Convert neighbors
            float3 yccUp = RGB2YUV(rgbUp);
            float3 yccDn = RGB2YUV(rgbDn);

            // Approximate PAL line alternation: invert V on one line before averaging.
            // Use current line parity to decide which neighbor to invert.
            const bool odd = ((gid.y & 1u) != 0u);
            float Vup = odd ? -yccUp.z : yccUp.z;
            float Vdn = odd ? yccDn.z  : -yccDn.z;

            float Uavg = 0.5f * (yccUp.y + yccDn.y);
            float Vavg = 0.5f * (Vup     + Vdn);

            // Blend towards delay-line average
            C1 = mix(C1, Uavg, u.PAL_BLEND);
            C2 = mix(C2, Vavg, u.PAL_BLEND);
        }

         // Optional chroma gain (helps compensate perceived desaturation after blur)
        C1 *= u.CHROMA_GAIN;
        C2 *= u.CHROMA_GAIN;
         */

        // Recombine and write
        /*
        float3 outRGB;
        if (isPAL) outRGB = YUV2RGB(float3(Y, C1, C2));
        else       outRGB = YIQ2RGB(float3(Y, C1, C2));
        */
    }

    /*
    kernel void composite(texture2d<half, access::sample> inTexture  [[ texture(0) ]],
                          texture2d<half, access::write>  outTexture [[ texture(1) ]],
                          constant Uniforms               &uniforms  [[ buffer(0)  ]],
                          constant PlaygroundUniforms     &u         [[ buffer(1)  ]],
                          sampler                         sam        [[ sampler(0) ]],
                          uint2                           gid        [[ thread_position_in_grid ]])
    {
        // Normalize gid to 0..1 in output texture
        float2 uvOut = (float2(gid) + 0.5) / float2(outTexture.get_width(), outTexture.get_height());

        // Remap to texRect in input texture
        float2 uvIn = uniforms.texRect.xy + uvOut * (uniforms.texRect.zw - uniforms.texRect.xy);

        // Sample input texture using normalized coords
        half4 color = inTexture.sample(sam, uvIn);

        outTexture.write(color, gid);
    }
    */

    inline float3 fetchRGB(float2 uv,
                                texture2d<half, access::sample> luma,
                                texture2d<half, access::sample> chroma,
                                sampler sam,
                                constant PlaygroundUniforms &u)
    {
        // Sample luma and chroma from textures
        float3 ycc = float3(luma.sample(sam, uv).x, chroma.sample(sam, uv).x, chroma.sample(sam, uv).y);

        // Convert to RGB depending on PAL/NTSC
        return (u.PAL == 1) ? YUV2RGB(ycc) : YIQ2RGB(ycc);
    }

    kernel void crt(texture2d<half, access::sample> luma       [[ texture(0) ]],
                    texture2d<half, access::sample> chroma     [[ texture(1) ]],
                    texture2d<half, access::write>  outTexture [[ texture(2) ]],
                    constant Uniforms               &uniforms  [[ buffer(0)  ]],
                    constant PlaygroundUniforms     &u         [[ buffer(1)  ]],
                    sampler                         sam        [[ sampler(0) ]],
                    uint2                           gid        [[ thread_position_in_grid ]])
    {
        // Normalize gid to 0..1 in output texture
        float2 uv = (float2(gid) + 0.5) / float2(outTexture.get_width(), outTexture.get_height());

        // Compose RGB value
        float3 rgb = fetchRGB(uv, luma, chroma, sam, u);

        outTexture.write(half4(half3(rgb), 1.0), gid);
        return;

        //
        // Experimental...
        //

        // float2 inize = float2(inTexture.get_width(), inTexture.get_height());
        // float2 outSize = float2(outTexture.get_width(), outTexture.get_height());


        // half4 color = inTexture.sample(sam, remap(float2(gid), outSize, uniforms.texRect));

        /*

        // Find the dot cell we are in
        uint2 maskSpacing = uint2(uint(u.GRID_WIDTH), uint(u.GRID_HEIGHT));

        // uint2 cell = gid / maskSpacing;
        float2 center = float2(uint2(gid / maskSpacing) * maskSpacing) + float2(maskSpacing) * 0.5;
        float2 centerL = center - float2(maskSpacing.x, 0.0);
        float2 centerR = center + float2(maskSpacing.x, 0.0);

        // Get the center weights from the blurred image
        half3 weight = half3(inTexture.sample(sam, center));
        half3 weightL = half3(inTexture.sample(sam, centerL));
        half3 weightR = half3(inTexture.sample(sam, centerR));


        // weight = weight; // 0.25 * weightL + 0.5 * weight + 0.25 * weightR;

        // Scale dot size based on weight
        float2 minDotSize = float2(u.MIN_DOT_WIDTH, u.MIN_DOT_HEIGHT);
        float2 maxDotSize = float2(u.MAX_DOT_WIDTH, u.MAX_DOT_HEIGHT);

        float2 scaledRDotSize = mix(minDotSize, maxDotSize, weight.r);
        float2 scaledRDotSizeL = mix(minDotSize, maxDotSize, weightL.r);
        float2 scaledRDotSizeR = mix(minDotSize, maxDotSize, weightR.r);

        float2 scaledGDotSize = mix(minDotSize, maxDotSize, weight.g);
        float2 scaledGDotSizeL = mix(minDotSize, maxDotSize, weightL.g);
        float2 scaledGDotSizeR = mix(minDotSize, maxDotSize, weightR.g);

        float2 scaledBDotSize = mix(minDotSize, maxDotSize, weight.b);
        float2 scaledBDotSizeL = mix(minDotSize, maxDotSize, weightL.b);
        float2 scaledBDotSizeR = mix(minDotSize, maxDotSize, weightR.b);

        // Compute relative position to dot centers

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

        // Clamp
        // glow = saturate(glow);

        // Modulate final glow by input color
        half3 result = u.BRIGHTNESS * pow(weight, 4.01 - 2 * u.GLOW) * half3(intensity);

        // Output (for now just grayscale, later modulate with input image color & size)
        outTexture.write(half4(result, 1.0), gid);
        */
    }

}
