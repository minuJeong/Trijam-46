#version 460
#define NEAR 0.02
#define FAR 100.0

in vec4 vs_position;

layout(location=0) out vec4 fs_color;
layout(location=1) out vec4 fs_normal;
layout(location=2) out vec4 fs_position;
layout(location=3) out vec4 fs_stencil;

uniform float u_aspect;
uniform vec2 u_control;
uniform float u_time;
uniform float u_char_xz_rotation;
uniform vec3 u_camerapos;
uniform float u_speed;

struct MarchingInfo
{
    vec3 charpos;
    vec4 color;
    float stencil;
};


float random(vec2 uv)
{
    return fract(sin(dot(uv, vec2(12.3412, 46.541)) * 43215.532143));
}

float sdf_sphere(vec3 p, float rad)
{
    return length(p) - rad;
}

float sdf_box(vec3 p, vec3 b)
{
    vec3 d = abs(p) - b;
    vec3 d0 = max(d, 0.0);
    vec3 d1 = min(d, 0.0);
    return length(d0) - max(d1.x, max(d1.y, d1.z));
}

float sdf_cylinder(vec3 p, float r, float height)
{
    float d = length(p.xz) - r;
    d = max(d, abs(p.y) - height);
    return d;
}

float sdf_capsule(vec3 p, float r, float c)
{
    float a = length(p.xz) - r;
    float b = length(vec3(p.x, abs(p.y) - c, p.z)) - r;
    float t = step(c, abs(p.y));
    return mix(a, b, t);
}

float sdf_line(vec3 p, vec3 a, vec3 b)
{
    vec3 ab = b - a;
    float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return length((ab * t + a) - p);
}

float sdf_plane(vec3 p, vec3 n, float offset)
{
    return dot(p, n) - offset;
}

float op_union_round(float a, float b, float t)
{
    vec2 uu = max(vec2(t - a, t - b), 0.0);
    return max(t, min(a, b)) - length(uu);
}

float op_union_chamfer(float a, float b, float r)
{
    return min(min(a, b), (a - r + b) * sqrt(0.5));
}

float op_union_stairs(float a, float b, float r, float n)
{
    float s = r / n;
    float u = b - r;
    return min(min(a, b), 0.5 * (u + a + abs ((mod(u - a + s, 2 * s)) - s)));
}

float p_mod_polar(inout vec2 p, float repetitions)
{
    float angle = 2.0 * 3.141592 / repetitions;
    float a = atan(p.y, p.x) + angle / 2.0;
    float r = length(p);
    float c = floor(a / angle);
    a = mod(a, angle) - angle / 2.0;
    p = vec2(cos(a), sin(a)) * r;
    if (abs(c) >= (repetitions / 2))
    {
        c = abs(c);
    }
    return c;
}

void pr(inout vec2 p, float a)
{
    p = cos(a) * p + sin(a) * vec2(p.y, -p.x);
}

mat2 rmat(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

float sdf_character(vec3 p, inout MarchingInfo info)
{
    vec3 p_char = p;
    p_char -= info.charpos;

    float ct = cos(u_char_xz_rotation - 0.707);
    float st = sin(u_char_xz_rotation - 0.707);
    p_char.xz = mat2(ct, st, -st, ct) * p_char.xz;

    float jump = cos(u_time * 3.14) * 0.5 + 0.5;
    jump = pow(jump, 3.0) * 1.44 + 0.7;
    p_char.y -= jump;

    float d_body = sdf_sphere(p_char, 1.2);
    float d_legs = FAR;
    {
        vec3 leg_p_a;
        vec3 leg_p_b;
        vec3 leg_p_c;
        float angle = 0.0;
        float angle_step = 6.2831856 / 13.0;

        for (int i = 0; i < 13; i++)
        {
            float c = cos(angle);
            float s = sin(angle);
            angle += angle_step;

            float foot = random(
                vec2(angle, (u_time * u_speed) * 0.000001)
            ) * 2.5;

            leg_p_a.xz = vec2(c, s) * (4.2 - foot * 0.5);
            leg_p_a.y = -1.0 - jump + foot;
            leg_p_b.xz = vec2(c, s) * 2.5;
            leg_p_b.y = 1.5 - jump * 0.25 + foot * 0.5;
            leg_p_c.xz = vec2(c, s) * 0.5;
            leg_p_c.y = -1.0;

            float d_leg = min(
                sdf_line(p_char, leg_p_a, leg_p_b),
                sdf_line(p_char, leg_p_b, leg_p_c)
            );

            d_legs = min(d_legs, d_leg - 0.15);
        }
    }

    float d_head = sdf_sphere(p_char - vec3(0.0, 0.3, -0.88), 0.7);

    float d = min(
        op_union_round(d_body, d_legs, 0.3),
        d_head
    );

    const vec4 LEG_COLOR = vec4(0.5, 0.5, 0.3, 1.0);
    if (d < NEAR)
    {
        // character
        info.stencil = 0.1;
        if (d_head > d_body)
        {
            if (d_body < d_legs)
            {
                info.color = vec4(0.5, 0.1, 0.2, 1.0);
            }
            else
            {
                info.color = LEG_COLOR;
            }
        }
        else
        {
            if (d_head < d_legs)
            {
                info.color = vec4(1.0, 0.1, 0.1, 1.0);
            }
            else
            {
                info.color = LEG_COLOR;
            }
        }
    }

    return d;
}

float sdf_forest(vec3 p, float d_floor, float terrain_height, inout MarchingInfo info)
{
    vec3 p_env = p;
    p_env.y -= 1.5 - terrain_height;

    vec2 repeat = vec2(8.6, 8.6);
    vec2 hrepeat = repeat * 0.5;
    p_env.xz = mod(p_env.xz + hrepeat, repeat) - hrepeat;

    vec2 XZ = floor(p.xz / repeat - hrepeat);
    float random = random(XZ);

    float height = 4.0 + random * 4.0;
    p_env.y += height * 0.5;
    float step_thick = 0.2 + random * 0.2;
    pr(p_env.xz, random * 3.14159 * 2.0);
    float d_box = sdf_box(
        p_env,
        vec3(step_thick, height, step_thick)
    ) - 0.1;
    d_box = op_union_round(d_box, d_floor, 0.5);

    vec3 p_leaves = p_env - vec3(0.0, height, 0.0);
    pr(p_leaves.xz, random * 3.14159);
    pr(p_leaves.yz, random * 0.5);

    p_leaves.xz -= vec2(0.5, -0.5);
    float d_sph_0 = sdf_sphere(p_leaves, 1.2);

    p_leaves.xz -= vec2(-1.5, 0.5);
    float d_sph_1 = sdf_sphere(p_leaves, 1.4);

    p_leaves.xz -= vec2(0.5, 0.5);
    float d_sph_2 = sdf_sphere(p_leaves, 1.5);

    float d_leaves = op_union_round(
        d_sph_0,
        op_union_round(d_sph_1, d_sph_2, 0.5),
        0.5
    );
    float d = min(d_box, d_leaves);

    if (d < NEAR)
    {
        // environment
        info.stencil = 0.2;
        if (d_box < d_leaves)
        {
            info.color = vec4(0.4, 0.4, 0.1, 1.0);
        }
        else
        {
            info.color = vec4(0.4, 0.7, 0.1, 1.0);
        }
    }

    return d;
}

float sdf_environment(vec3 p, inout MarchingInfo info)
{
    float d_floor = sdf_plane(p, vec3(0.0, 1.0, 0.0), -1.0);
    float d_forest = sdf_forest(p, d_floor, 0.0, info);
    return d_forest;
}

vec4 sdf(vec3 p, inout MarchingInfo info)
{
    // default color
    info.color = vec4(0.3, 0.3, 0.3, 1.0);

    float d_character = sdf_character(p, info);
    float d_environment = sdf_environment(p, info);

    float d = min(d_character, d_environment);
    return vec4(0.0, 1.0, 0.0, d);
}

vec4 raymarch(vec3 o, vec3 r, inout MarchingInfo info)
{
    vec3 p;
    vec4 d;
    vec4 t = vec4(0.0, 0.0, 0.0, 0.5);
    for (int i = 0; i < 64; i++)
    {
        p = o + r * t.w;
        d = sdf(p, info);
        if (d.w < NEAR || t.w > FAR) { break; }
        t.w += d.w;
    }
    return t;
}

mat3 lookat(vec3 o, vec3 t)
{
    vec3 UP = vec3(0.0, 1.0, 0.0);
    vec3 F = normalize(t - o);
    vec3 R = cross(F, UP);
    vec3 U = cross(R, F);
    return mat3(R, U, F);
}

vec3 normalat(vec3 p, MarchingInfo info)
{
    const vec2 e = vec2(0.002, 0.0);
    return normalize(vec3(
        sdf(p + e.xyy, info).w - sdf(p - e.xyy, info).w,
        sdf(p + e.yxy, info).w - sdf(p - e.yxy, info).w,
        sdf(p + e.yyx, info).w - sdf(p - e.yyx, info).w
    ));
}

void main()
{
    vec2 uv = vs_position.xy;
    uv.x *= u_aspect;

    vec2 offset = u_control.xy;
    offset = mat2(-0.707, 0.707, -0.707, -0.707) * offset;

    vec3 org = u_camerapos;
    org.xz += offset;

    MarchingInfo info;

    vec3 charpos = vec3(0.0);
    charpos.xz += offset;
    info.charpos = charpos;

    vec3 ray = lookat(org, charpos + vec3(0.0, 0.5, 0.0)) * normalize(vec3(uv, 1.0));

    vec3 RGB = vec3(0.1 - vs_position.y * 0.05);
    vec4 scene = raymarch(org, ray, info);

    fs_color = vec4(info.color.xyz, scene.w);
    fs_normal = vec4(0.0);
    fs_position = vec4(0.0, 0.0, 0.0, scene.w);
    fs_stencil = vec4(0.0);
    if (scene.w < FAR)
    {
        vec3 P = org + ray * scene.w;
        vec3 N = normalat(P, info);

        fs_normal.xyz = N * 0.5 + 0.5;
        fs_normal.w = 1.0;
        fs_position.xyz = P;
        fs_stencil.x = info.stencil;
    }
}
