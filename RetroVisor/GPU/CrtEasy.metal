// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

// This shader is an experimental MSL port of
// https://github.com/libretro/common-shaders/blob/master/crt/shaders/crt-easymode.cg

#include <metal_stdlib>

using namespace metal;

namespace crteasy {
    
    struct CrtUniforms {
        
        float BRIGHT_BOOST;
        float DILATION;
        float GAMMA_INPUT;
        float GAMMA_OUTPUT;
        float MASK_SIZE;
        float MASK_STAGGER;
        float MASK_STRENGTH;
        float MASK_DOT_WIDTH;
        float MASK_DOT_HEIGHT;
        float SCANLINE_BEAM_WIDTH_MAX;
        float SCANLINE_BEAM_WIDTH_MIN;
        float SCANLINE_BRIGHT_MAX;
        float SCANLINE_BRIGHT_MIN;
        float SCANLINE_CUTOFF;
        float SCANLINE_STRENGTH;
        float SHARPNESS_H;
        float SHARPNESS_V;
        uint  ENABLE_LANCZOS;
        
        float2 resolution;
        float2 window;
    };
    
    constant constexpr float M_PI = 3.14159265358979323846264338327950288;
    
    inline float FIX(float c) { return max(fabs(c), 1e-5); }
    // inline float2 FIX(float2 c) { return max(fabs(c), 1e-5); }
    // inline float4 FIX(float4 c) { return max(fabs(c), 1e-5); }
    inline float4 dilate(float4 col, float DILATION) {
        float4 x = mix(float4(1.0), col, DILATION);
        return col * x;
    }
    inline float4 TEX2D(texture2d<float, access::sample> tex, sampler s, float2 c, float DILATION) {
        return dilate(tex.sample(s, c), DILATION);
    }
    inline float mod(float x, float y) {
        return x - y * trunc(x / y);
    }
    
    inline float2 mod(float2 x, float2 y) {
        return x - y * trunc(x / y);
    }
    
    inline float3 mod(float3 x, float3 y) {
        return x - y * trunc(x / y);
    }
    
    inline float curve_distance(float x, float sharp) {
        float x_step = (x >= 0.5) ? 1.0 : 0.0;
        float curve = 0.5 - sqrt(0.25 - (x - x_step) * (x - x_step)) * ((0.5 - x) >= 0.0 ? 1.0 : -1.0);
        return mix(x, curve, sharp);
    }
    
    inline float4x4 get_color_matrix(texture2d<float> tex, sampler sam, float2 co, float2 dx, float DILATION) {
        return float4x4(
                        dilate(tex.sample(sam, co - dx), DILATION),
                        dilate(tex.sample(sam, co), DILATION),
                        dilate(tex.sample(sam, co + dx), DILATION),
                        dilate(tex.sample(sam, co + 2.0 * dx), DILATION)
                        );
    }
    
    inline float3 filter_lanczos(float4 coeffs, float4x4 color_matrix) {
        float4 col = coeffs.x * color_matrix[0] +
        coeffs.y * color_matrix[1] +
        coeffs.z * color_matrix[2] +
        coeffs.w * color_matrix[3];
        
        float4 sample_min = min(color_matrix[1], color_matrix[2]);
        float4 sample_max = max(color_matrix[1], color_matrix[2]);
        
        col = clamp(col, sample_min, sample_max);
        
        return col.rgb;
    }
    
    inline float4 crt_easymode(float2 texture_size,
                               float2 video_size,
                               float2 output_size,
                               float2 tex_norm,
                               float2 coords,
                               texture2d<float> tex,
                               sampler sam,
                               constant CrtUniforms& u) {
        
        float2 dx = float2(1.0 / texture_size.x, 0.0);
        float2 dy = float2(0.0, 1.0 / texture_size.y);
        float2 pix_co = coords * texture_size - float2(0.5);
        float2 tex_co = (floor(pix_co) + float2(0.5)) / texture_size;
        float2 dist = fract(pix_co);
        float curve_x;
        float3 col, col2;
        
        if (u.ENABLE_LANCZOS) {
            
            curve_x = curve_distance(dist.x, u.SHARPNESS_H * u.SHARPNESS_H);
            
            float4 coeffs = M_PI * float4(1.0 + curve_x, curve_x, 1.0 - curve_x, 2.0 - curve_x);
            coeffs = max(abs(coeffs), 1e-5);
            coeffs = 2.0 * sin(coeffs) * sin(coeffs / 2.0) / (coeffs * coeffs);
            coeffs /= dot(coeffs, float4(1.0));
            
            col = filter_lanczos(coeffs, get_color_matrix(tex, sam, tex_co, dx, u.DILATION));
            col2 = filter_lanczos(coeffs, get_color_matrix(tex, sam, tex_co + dy, dx, u.DILATION));
            
        } else {
            
            curve_x = curve_distance(dist.x, u.SHARPNESS_H);
            
            col = mix(tex.sample(sam, tex_co).rgb,
                      tex.sample(sam, tex_co + dx).rgb,
                      curve_x);
            col2 = mix(tex.sample(sam, tex_co + dy).rgb,
                       tex.sample(sam, tex_co + dx + dy).rgb,
                       curve_x);
        }
        
        col = mix(col, col2, curve_distance(dist.y, u.SHARPNESS_V));
        col = pow(col, float3(u.GAMMA_INPUT / (u.DILATION + 1.0)));
        
        float luma = dot(col, float3(0.2126, 0.7152, 0.0722));
        float bright = (max(col.r, max(col.g, col.b)) + luma) / 2.0;
        float scan_bright = clamp(bright, u.SCANLINE_BRIGHT_MIN, u.SCANLINE_BRIGHT_MAX);
        float scan_beam = clamp(bright * u.SCANLINE_BEAM_WIDTH_MAX,
                                u.SCANLINE_BEAM_WIDTH_MIN,
                                u.SCANLINE_BEAM_WIDTH_MAX);
        
        /*
         float scan_weight = 1.0 - pow(cos(coords.y * 2.0 * M_PI * texture_size.y) * 0.5 + 0.5,
         scan_beam) * u.SCANLINE_STRENGTH;
         */
        float scan_weight = 1.0 - pow(cos(tex_norm.y * 0.5 * M_PI * output_size.y) * 0.5 + 0.5,
                                      scan_beam) * u.SCANLINE_STRENGTH;
        
        float mask = 1.0 - u.MASK_STRENGTH;
        /*
         float2 mod_fac = floor(coords * output_size * texture_size / (video_size *
         float2(u.MASK_SIZE, u.MASK_DOT_HEIGHT * u.MASK_SIZE)));
         */
        float2 mod_fac = floor(tex_norm * output_size / float2(u.MASK_SIZE, u.MASK_DOT_HEIGHT * u.MASK_SIZE));
        int dot_no = int(fmod((mod_fac.x + fmod(mod_fac.y, 2.0) * u.MASK_STAGGER) / u.MASK_DOT_WIDTH, 3.0));
        float3 mask_weight;
        
        if (dot_no == 0)
            mask_weight = float3(1.0, mask, mask);
        else if (dot_no == 1)
            mask_weight = float3(mask, 1.0, mask);
        else
            mask_weight = float3(mask, mask, 1.0);
        
        if (video_size.y >= u.SCANLINE_CUTOFF)
            scan_weight = 1.0;
        
        col2 = col;
        col *= float3(scan_weight);
        col = mix(col, col2, scan_bright);
        col *= mask_weight;
        col = pow(col, float3(1.0 / u.GAMMA_OUTPUT));
        
        return float4(col * u.BRIGHT_BOOST, 1.0);
    }
        
    // Compute kernel variant
    kernel void crtEasy(texture2d<float, access::sample> inTexture   [[ texture(0) ]],
                        texture2d<float, access::write>  outTexture  [[ texture(1) ]],
                        constant CrtUniforms             &u          [[ buffer(0) ]],
                        sampler                          sam         [[ sampler(0) ]],
                        uint2                            gid         [[ thread_position_in_grid ]])
    {
        // (Optional) bounds check if you over-dispatch:
        // if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
        
        float2 texture_size = u.resolution;
        float2 video_size   = u.window;
        float2 output_size  = u.window;
        
        // 1) Compute-space -> normalized output UV at pixel center
        float2 outSize = float2(outTexture.get_width(), outTexture.get_height());
        float2 uvOut   = (float2(gid) + 0.5) / outSize;
        
        // 2) Map into texRect (normalized 0..1 on input texture)
        float2 texOrigin = float2(0,0); //  uniforms.texRect.xy;
        float2 texSize   = float2(1.0, 1.0); // uniforms.texRect.zw - uniforms.texRect.xy;
        float2 texCoord  = texOrigin + uvOut * texSize;
        
        // 3) The same "normuv" as used in the fragment path
        float2 normuv = (texCoord - texOrigin) / texSize;
        
        float4 result = crt_easymode(texture_size,
                                     video_size,
                                     output_size,
                                     normuv,       // same as fragment's normuv
                                     texCoord,     // same as fragment's in.texCoord
                                     inTexture,
                                     sam,
                                     u);
        
        outTexture.write(result, gid);
    }
}
