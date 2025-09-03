// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#ifndef MATH_TOOLBOX_METAL
#define MATH_TOOLBOX_METAL

typedef float   Coord;
typedef float2  Coord2;

constant constexpr float M_PI = 3.14159265358979323846264338327950288;

template<typename T>
inline T sigmoid(T x, float k) {
    return 1.0 / (1.0 + exp(-k * (x - 0.5)));
}

#endif
