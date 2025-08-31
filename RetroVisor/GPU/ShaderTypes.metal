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

    float INPUT_TEX_SCALE;
    float OUTPUT_TEX_SCALE;
    uint  RESAMPLE_FILTER;

    // Chroma phase
    uint  PAL;
    float CHROMA_RADIUS;

    // Bloom effect
    uint  BLOOM_ENABLE;
    uint  BLOOM_FILTER;
    float BLOOM_THRESHOLD;
    float BLOOM_INTENSITY;
    float BLOOM_RADIUS_X;
    float BLOOM_RADIUS_Y;

    /*
    uint  SCANLINE_ENABLE;
    float SCANLINE_BRIGHTNESS;
    float SCANLINE_WEIGHT1;
    float SCANLINE_WEIGHT2;
    float SCANLINE_WEIGHT3;
    float SCANLINE_WEIGHT4;
     */

    // Shadow mask
    uint  SHADOW_ENABLE;
    float BRIGHTNESS;
    float GLOW;
    float SHADOW_GRID_WIDTH;
    float SHADOW_GRID_HEIGHT;
    float SHADOW_DOT_WIDTH;
    float SHADOW_DOT_HEIGHT;
    float SHADOW_DOT_WEIGHT;
    float SHADOW_DOT_GLOW;
    float SHADOW_FEATHER;

    // Dot mask
    uint  DOTMASK_ENABLE;
    uint  DOTMASK;
    float DOTMASK_BRIGHTESS;

    uint  DEBUG_ENABLE;
    uint  DEBUG_TEXTURE;
    float DEBUG_SLIDER;
};

#endif
