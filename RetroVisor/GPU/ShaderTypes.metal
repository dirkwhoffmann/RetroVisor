// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#ifndef SHADER_TYPES
#define SHADER_TYPES

#include <metal_stdlib>

using namespace metal;

struct VertexIn {

    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {

    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {

    float time;
    float2 shift;
    float zoom;
    float intensity;
    float2 resolution;
    float2 window;
    float2 center;
    float2 mouse;
};

#endif
