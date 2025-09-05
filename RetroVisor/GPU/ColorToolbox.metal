// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#ifndef COLOR_TOOLBOX_METAL
#define COLOR_TOOLBOX_METAL

#include <metal_stdlib>

using namespace metal;

typedef half    Color;
typedef half3   Color3;
typedef half4   Color4;

inline Color3 RGB2HSV(Color3 rgb) {
    
    Color4 K = Color4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    Color4 p = (rgb.g < rgb.b) ? Color4(rgb.bg, K.wz) : Color4(rgb.gb, K.xy);
    Color4 q = (rgb.r < p.x) ? Color4(p.xyw, rgb.r) : Color4(rgb.r, p.yzx);

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;

    float h = abs(q.z + (q.w - q.y) / (6.0 * d + e));
    float s = d / (q.x + e);
    float v = q.x;

    return Color3(h, s, v);
}

inline Color4 RGB2HSV(Color4 rgba) {

    return Color4(RGB2HSV(Color3(rgba)), rgba.a);
}

inline Color3 HSV2RGB(Color3 hsv) {
    
    Color4 K = Color4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    Color3 p = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
    return hsv.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
}

inline Color4 HSV2RGB(Color4 hsva) {

    return Color4(HSV2RGB(Color3(hsva)), hsva.a);
}

inline Color3 RGB2YIQ(Color3 rgb) {
    
    Color3 yiq = Color3(dot(rgb, Color3(0.299,  0.587,  0.114)),   // Y
                        dot(rgb, Color3(0.596, -0.274, -0.322)),   // I
                        dot(rgb, Color3(0.211, -0.523,  0.312)));  // Q

    // Shift chroma from [-0.5;0.5] to [0.0;1.0]
    return Color3(yiq.x, yiq.y + 0.5, yiq.z + 0.5);
}

inline Color4 RGB2YIQ(Color4 rgba) {

    return Color4(RGB2YIQ(Color3(rgba)), rgba.a);
}

inline Color3 YIQ2RGB(Color3 yiq) {
    
    // Shift chroma from [0.0;1.0] to [-0.5;0.5]
    yiq = Color3(yiq.x, yiq.y - 0.5, yiq.z - 0.5);
    
    Color Y = yiq.x, I = yiq.y, Q = yiq.z;
    Color3 rgb = Color3(Y + 0.956 * I + 0.621 * Q,
                        Y - 0.272 * I - 0.647 * Q,
                        Y - 1.106 * I + 1.703 * Q);
    return clamp(rgb, 0.0, 1.0);
}

inline Color4 YIQ2RGB(Color4 yiqa) {

    return Color4(YIQ2RGB(Color3(yiqa)), yiqa.a);
}

inline Color3 RGB2YUV(Color3 rgb) {
    
    // PAL-ish YUV (BT.601)
    Color3 yuv = Color3(dot(rgb, Color3(0.299,     0.587,    0.114)),    // Y
                        dot(rgb, Color3(-0.14713, -0.28886,  0.436)),    // U
                        dot(rgb, Color3(0.615,    -0.51499, -0.10001))); // V

    // Shift chroma from [-0.5;0.5] to [0.0;1.0]
    return Color3(yuv.x, yuv.y + 0.5, yuv.z + 0.5);
}

inline Color4 RGB2YUV(Color4 rgba) {

    return Color4(RGB2YUV(Color3(rgba)), rgba.a);
}

inline Color3 YUV2RGB(Color3 yuv) {

    // Shift chroma from [0.0;1.0] to [-0.5;0.5]
    yuv = Color3(yuv.x, yuv.y - 0.5, yuv.z - 0.5);
    
    Color Y = yuv.x, U = yuv.y, V = yuv.z;
    Color3 rgb = Color3(Y + 1.13983 * V,
                        Y - 0.39465 * U - 0.58060 * V,
                        Y + 2.03211 * U);
    return clamp(rgb, 0.0, 1.0);
}

inline Color4 YUV2RGB(Color4 yuva) {

    return Color4(YUV2RGB(Color3(yuva)), yuva.a);
}


#endif
