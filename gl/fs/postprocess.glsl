#version 460

in vec4 vs_position;
out vec4 fs_color;

layout(binding=0) uniform sampler2D u_gbuffer_color;
layout(binding=1) uniform sampler2D u_gbuffer_normal;
layout(binding=2) uniform sampler2D u_gbuffer_position;
layout(binding=3) uniform sampler2D u_gbuffer_stencil;
layout(binding=4) uniform sampler2D u_gbuffer_depth;

const vec3 LIGHT_POS = vec3(-10.0, 30.0, -40.0);

void main()
{
    vec2 uv = vs_position.xy * 0.5 + 0.5;

    vec4 texcolor = texture(u_gbuffer_color, uv);
    vec4 texnormal = texture(u_gbuffer_normal, uv);
    vec4 texposition = texture(u_gbuffer_position, uv);
    vec4 texstencil = texture(u_gbuffer_stencil, uv);
    
    float depth = texcolor.w;

    vec3 P = texposition.xyz;
    vec3 L = normalize(LIGHT_POS - P);
    vec3 N = texnormal.xyz * 2.0 - 1.0;

    float lambert = dot(N, L);
    lambert = max(lambert, 0.0);

    fs_color = vec4(lambert.xxx, 1.0);
}