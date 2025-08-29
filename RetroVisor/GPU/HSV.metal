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

namespace hsv {

    struct HSVUniforms {

        uint  H_ENABLE;
        float H_VALUE;

        uint  S_ENABLE;
        float S_VALUE;

        uint  V_ENABLE;
        float V_VALUE;
    };

    //
    // Color space helpers
    //

    #define USE_OPTIMIZED_HSV   1   // set to 0 for readable version

#if USE_OPTIMIZED_HSV

    float3 rgb2hsv(float3 c) {
        float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
        float4 p = (c.g < c.b) ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
        float4 q = (c.r < p.x) ? float4(p.xyw, c.r) : float4(c.r, p.yzx);

        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;

        float h = abs(q.z + (q.w - q.y) / (6.0 * d + e));
        float s = d / (q.x + e);
        float v = q.x;

        return float3(h, s, v);
    }

#else // Readable version

    float3 rgb2hsv(float3 c) {
        float r = c.r, g = c.g, b = c.b;

        float maxc = max(r, max(g, b));
        float minc = min(r, min(g, b));
        float delta = maxc - minc;

        float h = 0.0;
        float s = (maxc > 0.0) ? (delta / maxc) : 0.0;
        float v = maxc;

        if (delta > 1e-6) {
            if (maxc == r) {
                h = (g - b) / delta;
                if (h < 0.0) h += 6.0;
            } else if (maxc == g) {
                h = (b - r) / delta + 2.0;
            } else {
                h = (r - g) / delta + 4.0;
            }
            h /= 6.0;
        }

        return float3(h, s, v);
    }

#endif

#if USE_OPTIMIZED_HSV

    float3 hsv2rgb(float3 c) {
        float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
        float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }

#else // Readable version

    float3 hsv2rgb(float3 c) {
        float h = c.x, s = c.y, v = c.z;

        if (s <= 0.0) {
            return float3(v, v, v); // grayscale
        }

        h = fract(h) * 6.0;
        int i = int(floor(h));
        float f = h - float(i);

        float p = v * (1.0 - s);
        float q = v * (1.0 - s * f);
        float t = v * (1.0 - s * (1.0 - f));

        if (i == 0) return float3(v, t, p);
        if (i == 1) return float3(q, v, p);
        if (i == 2) return float3(p, v, t);
        if (i == 3) return float3(p, q, v);
        if (i == 4) return float3(t, p, v);
        return float3(v, p, q);
    }

#endif

    kernel void hsv(texture2d<half, access::sample> inTex     [[ texture(0) ]],
                    texture2d<half, access::write>  outTex    [[ texture(1) ]],
                    constant HSVUniforms            &u        [[ buffer(0)  ]],
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
        float3 hsv = rgb2hsv(float3(rgb));

        if (u.H_ENABLE) hsv.x = u.H_VALUE;
        if (u.S_ENABLE) hsv.y = u.S_VALUE;
        if (u.V_ENABLE) hsv.z = u.V_VALUE;

        rgb = Color3(hsv2rgb(hsv));
        outTex.write(Color4(rgb, 1.0), gid);
    }

}
