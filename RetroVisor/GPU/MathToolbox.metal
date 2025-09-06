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
 *
 *   a ∈ [0, 1] – Controls the curve shape:
 *                values < 0.5 bend the curve toward 1 (convex),
 *                values > 0.5 bend it toward 0 (concave).
 *
 * Note: The function is nearly symmetric around a ≈ 0.5, but not exact,
 *       in order to keep the implementation efficient.
 */

template<typename T>
inline T remap(T x, float a) {
    
    return pow(x, 0.25 + 4.0 * a * a);
}

/* Remap variant with controllable bending strength
 *
 * Parameters:
 *   a ∈ [0, 1] – Controls the curve shape as above.
 *
 *   b ∈ [0, 1] – Controls the bending strength:
 *                smaller values produce a gentler curve,
 *                larger values produce a stronger curve.
 */
template<typename T>
inline T remap(T x, float a, float b) {
    
    a = mix(0.5 - 0.5 * abs(b), 0.5 + 0.5 * abs(b), a);
    return pow(x, 0.25 + (4.0 * a * a));
}

/* Remap variant with individual bending strengths for concave and convex curves.
 *
 * Parameters:
 *
 *   a  ∈ [0, 1] – Controls the curve shape as above.
 *   b1 ∈ [0, 1] – Controls the bending strength for convex curves.
 *   b2 ∈ [0, 1] – Controls the bending strength for concave curves.
*/
template<typename T>
inline T remap(T x, float a, float b1, float b2) {

    a *= 2;
    if (a < 1.0) {
        a = mix(0.5 - 0.5 * abs(b1), 0.5, a);
    } else {
        a = mix(0.5, 0.5 + 0.5 * abs(b2), a - 1);
    }
    return pow(x, 0.25 + (4.0 * a * a));
}

/* Remap variant with more pronounced curving.
 *
 * Parameters:
 *
 *   a  ∈ [0, 1] – Controls the curve shape as above.
 *   b1 ∈ [0, 1] – Controls the bending strength as above.
 *   b2 ∈ [0, 1] – Controls the bending strength as above.
*/
template<typename T>
inline T remapXL(T x, float a, float b1, float b2) {

    a *= 2;
    if (a < 1.0) {
        a = mix(0.5 - 0.5 * abs(b1), 0.5, a);
    } else {
        a = mix(0.5, 0.5 + 0.5 * abs(b2), a - 1);
    }
    return pow(x, 0.125 + (8.0 * a * a * a));
}


/* Remap function used in older implementations.
 * Let's keep it for inspiration...
 */
inline half4 remap8(half4 x, float weight) {
    
    return pow(x, pow(mix(1.2, 0.8, weight), 8));
}

#endif
