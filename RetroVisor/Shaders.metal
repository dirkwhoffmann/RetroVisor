#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertex_main(const device float4* vertexArray [[ buffer(0) ]],
                             uint vertexId [[ vertex_id ]]) {
    VertexOut out;
    out.position = vertexArray[vertexId];
    out.texCoord = float2((vertexArray[vertexId].xy + 1.0) * 0.5);
    return out;
}

fragment float4 fragment_main(VertexOut in [[ stage_in ]],
                              texture2d<float> inputTexture [[ texture(0) ]],
                              sampler textureSampler [[ sampler(0) ]]) {
    const float4 color = inputTexture.sample(textureSampler, in.texCoord);
    return color;
}
