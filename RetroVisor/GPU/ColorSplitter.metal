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

namespace colorsplit {

    struct Uniforms {

        uint  COLOR_SPACE;
        uint  FILTER;

        uint  X_ENABLE;
        float X_VALUE;

        uint  Y_ENABLE;
        float Y_VALUE;

        uint  Z_ENABLE;
        float Z_VALUE;
    };

    kernel void splitter(texture2d<half, access::sample> src  [[ texture(0) ]],
                         texture2d<half, access::write>  dst  [[ texture(1) ]],
                         constant Uniforms               &u   [[ buffer(0)  ]],
                         sampler                         sam  [[ sampler(0) ]],
                         uint2                           gid  [[ thread_position_in_grid ]])
    {
        // Normalize gid to [0..1]
        Coord2 uv = (Coord2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());;

        // Read pixel
        Color3 xyz = Color3(src.sample(sam, uv).rgb);

        switch (u.COLOR_SPACE) {
                
            case 1: xyz = RGB2HSV(xyz); break;
            case 2: xyz = RGB2YUV(xyz); break;
            case 3: xyz = RGB2YIQ(xyz); break;
            default: break;
        }

        switch (u.FILTER) {
                
            case 0: xyz = xyz.xxx; break;
            case 1: xyz = xyz.yyy; break;
            case 2: xyz = xyz.zzz; break;

            default:
                
                if (u.X_ENABLE) xyz.x = u.X_VALUE;
                if (u.Y_ENABLE) xyz.y = u.Y_VALUE;
                if (u.Z_ENABLE) xyz.z = u.Z_VALUE;
                
                switch (u.COLOR_SPACE) {
                    case 1: xyz = HSV2RGB(xyz); break;
                    case 2: xyz = YUV2RGB(xyz); break;
                    case 3: xyz = YIQ2RGB(xyz); break;
                    default: break;
                }
        }
        
        dst.write(Color4(xyz, 1.0), gid);
    }
}
