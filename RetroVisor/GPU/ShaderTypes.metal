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
    float zoom;
    float intensity;
    float2 resolution;
    float2 window;
    float2 center;
    float2 mouse;
    float4 texRect;
};

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
};

struct PlaygroundUniforms {

    float BRIGHTNESS;
    float GRID_WIDTH;
    float GRID_HEIGHT;
    float MIN_DOT_WIDTH;
    float MAX_DOT_WIDTH;
    float MIN_DOT_HEIGHT;
    float MAX_DOT_HEIGHT;
    float SHAPE;
    float FEATHER;
};

#endif
