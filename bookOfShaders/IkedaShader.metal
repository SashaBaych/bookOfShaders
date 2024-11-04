#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    packed_float2 resolution;
    packed_float2 mouse;
    float time;
};

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

float random(float x) {
    return metal::fract(sin(x) * 10000.0);
}

float random(float2 st) {
    return metal::fract(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
}

float pattern(float2 st, float2 v, float t) {
    float2 p = floor(st + v);
    return step(t, random(100.0 + p * 0.000001) + random(p.x) * 0.5);
}

vertex VertexOut vertex_shader(const VertexIn vertex_in [[stage_in]]) {
    VertexOut out;
    out.position = vertex_in.position;
    out.texCoord = vertex_in.texCoord;
    return out;
}

fragment float4 fragment_shader(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 st = in.texCoord;
    st.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float2 grid = float2(100.0, 50.0);
    st *= grid;
    
    float2 ipos = floor(st);
    float2 fpos = metal::fract(st);
    
    float2 vel = float2(uniforms.time * 0.5 * max(grid.x, grid.y));
    vel *= float2(-1.0, 0.0) * random(1.0 + ipos.y);
    
    float2 offset = float2(0.1, 0.0);
    float3 color = float3(0.0);
    
    float mouseX = uniforms.mouse.x / uniforms.resolution.x;
    color.r = pattern(st + offset, vel, 0.5 + mouseX);
    color.g = pattern(st, vel, 0.5 + mouseX);
    color.b = pattern(st - offset, vel, 0.5 + mouseX);
    
    color *= step(0.2, fpos.y);
    
    return float4(1.0 - color, 1.0);
}
