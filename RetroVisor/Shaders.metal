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

//
// Vertex shader
//

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}
/*
vertex VertexOut vertex_main(const device VertexIn *vertices [[buffer(0)]],
                             ushort vid [[vertex_id]])
{
    VertexOut out;
    out.position = vertices[vid].position;
    out.texCoord = vertices[vid].texCoord;
    return out;
}
*/

//
// Fragment shader
//

/*
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {

    float4 color = tex.sample(sam, in.texCoord);
    return color;
}
*/

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    float4 color = tex.sample(sam, in.texCoord);

    float r = color.r;
    float g = color.g;
    float b = color.b;

    float sepiaR = min(1.0, 0.44 * r + 0.77 * g + 0.20 * b);
    float sepiaG = min(1.0, 0.39 * r + 0.70 * g + 0.17 * b);
    float sepiaB = min(1.0, 0.23 * r + 0.52 * g + 0.10 * b);

    return float4(sepiaR, sepiaG, sepiaB, color.a);
}
