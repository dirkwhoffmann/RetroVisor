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

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler s [[sampler(0)]]) {
    return tex.sample(s, in.texCoord);
}
/*
fragment float4 fragment_main(VertexOut in [[ stage_in ]],
                              texture2d<float> inputTexture [[ texture(0) ]],
                              sampler textureSampler [[ sampler(0) ]]) {
    const float4 color = inputTexture.sample(textureSampler, in.texCoord);
    return color;
}
*/
