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

/* Remaps the unit interval [0 ... 1] to [0 ... 1] using a pow-based function.
 *
 * Parameters:
 *   a ∈ [0, 1] – Controls the curve shape:
 *                values < 0.5 bend the curve toward 0 (concave),
 *                values > 0.5 bend it toward 1 (convex).
 *
 *   b ∈ [0, 2] – Controls the bending strength:
 *                smaller values produce a gentler curve,
 *                larger values produce a stronger curve.
 *
 * Notes:
 * - The function is nearly symmetric around a ≈ 0.5, but not exact,
 *   in order to keep the implementation efficient.
 */
template<typename T>
inline T remap(T x, float a, float b) {
    return pow(x, 0.25f + pow(4.0f * (1 - a) * (1 - a), b));
}

#endif
