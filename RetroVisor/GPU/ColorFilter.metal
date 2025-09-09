// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#include "MathToolbox.metal"
#include "ColorToolbox.metal"

using namespace metal;

namespace colorfilter {

    struct Uniforms {

        uint  PALETTE;
        float BRIGHTNESS;
        float CONTRAST;
        float SATURATION;
        
        uint  BLUR_ENABLE;
        uint  BLUR_FILTER;
        float BLUR_RADIUS_X;
        float BLUR_RADIUS_Y;
        
        uint  RESAMPLE_FILTER;
        float RESAMPLE_SCALE_X;
        float RESAMPLE_SCALE_Y;
    };
    
    kernel void colorizer(texture2d<half, access::sample> src  [[ texture(0) ]],
                          texture2d<half, access::write>  dst  [[ texture(1) ]],
                          constant Uniforms               &u   [[ buffer(0)  ]],
                          sampler                         sam  [[ sampler(0) ]],
                          uint2                           gid  [[ thread_position_in_grid ]])
    {
        // Normalize gid to [0..1]
        Coord2 uv = (Coord2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());

        // Read pixel
        Color3 rgb = src.sample(sam, uv).rgb;

        // Apply gamma correction
        rgb = pow(rgb, 2.2);

        // Convert RGB to YUV
        Color3 yuv = RGB2YUV(rgb);
        Color Y = yuv.x;
        Color U = yuv.y;
        Color V = yuv.z;
        
        // Transform color palette
        switch(u.PALETTE) {

            case 1: // BLACK_WHITE
                
                U = 0.0;
                V = 0.0;
                break;

            case 2: // PAPER_WHITE
                
                U = (-128.0 + 120.0) / 255.0;
                V = (-128.0 + 133.0) / 255.0;
                break;

            case 3: // GREEN
                
                U = (-128.0 + 29.0) / 255.0;
                V = (-128.0 + 64.0) / 255.0;
                break;

            case 4: // AMBER
                
                U = (-128.0 + 24.0) / 255.0;
                V = (-128.0 + 178.0) / 255.0;
                break;

            case 5: // SEPIA
                
                U = (-128.0 + 97.0) / 255.0;
                V = (-128.0 + 154.0) / 255.0;
                break;

            default: // COLOR
                
                break;
        }

        // Modulate saturation, contrast, and brightness
        Y = (Y - 0.5) * (0.5 + u.CONTRAST) + 0.5 + (u.BRIGHTNESS - 0.5);
        U = U * (u.SATURATION + 0.5);
        V = V * (u.SATURATION + 0.5);

        // Convert YUV to RGB
        rgb = YUV2RGB(Color3(Y, U, V));
        
        // Reverse Gamma correction
        rgb = pow(rgb, Color3(1.0 / 2.2));

        dst.write(Color4(rgb, 1.0), gid);
    }
}
