#version 440
// Pain's techniques over the lock-screen wallpaper:
//  - charge:  the world dims to grey-violet and is drawn in slightly
//  - wave:    Shinra Tensei, a shockwave blasting everything outward
//             (displacement band + chromatic ring + dust + flash + shake)
//  - pull:    Bansho Ten'in, space pulled in towards `center` with chakra streaks
//  - eye:     two giant almond-shaped Rinnegan eyes (assets/rinnegan.png)
//             glowing in the dark, like the anime close-up
// Compile with:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o shinra.frag.qsb shinra.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // px
    vec2 center;     // px
    float radius;    // px, inner radius for the Bansho streaks
    vec2 eyeL;       // px, left Rinnegan centre
    vec2 eyeR;       // px, right Rinnegan centre
    vec2 eyeSize;    // px, half width / half height of an open eye
    float reach;     // px, falloff for charge / pull
    float eye;       // 0..1 Rinnegan eyes opening
    float charge;    // 0..1
    float wave;      // 0..1 shockwave progress (0 = none)
    float flash;     // 0..1
    float pull;      // 0..1 Bansho Ten'in strength
    float shake;     // px
    float time;      // seconds
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D eyeTex;

const float TAU = 6.28318531;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + 7.3; a *= 0.5; }
    return v;
}

vec2 rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// One glowing Rinnegan eye. tilt > 0 lifts the outer (left) corner.
// Returns rgb in .rgb and coverage in .a, plus glow added separately.
vec4 rinneganEye(vec2 px, vec2 c, float tilt, float open, out float glow) {
    vec2 l = rot(px - c, -tilt);
    float W = eyeSize.x;
    float H = eyeSize.y * open;
    float x = l.x / W;
    // almond: lids meet in sharp corners, upper lid a bit fuller
    float lid = max(1.0 - x * x, 0.0);
    float top = H * pow(lid, 0.85) * 1.05;
    float bot = H * pow(lid, 1.1) * 0.85;
    float e = (l.y < 0.0) ? (-l.y - top) : (l.y - bot);   // >0 outside, px-ish
    e = max(e, (abs(x) - 1.0) * W);
    glow = exp(-max(e, 0.0) / (eyeSize.y * 0.45)) * open;
    float inside = 1.0 - smoothstep(-1.0, 1.0, e);
    if (inside <= 0.0) return vec4(0.0);
    // iris larger than the opening, so the lids cut the outer rings
    float Ri = eyeSize.y * 1.25;
    vec4 t = texture(eyeTex, clamp(l / Ri * 0.5 + 0.5, 0.0, 1.0));
    vec3 sclera = vec3(0.84, 0.76, 0.97);
    vec3 ic = t.rgb / max(t.a, 1e-3);
    vec3 col = mix(sclera, ic, t.a * step(length(l), Ri));
    // lit from within, darker towards the lids
    col *= 0.8 + 0.35 * smoothstep(0.0, eyeSize.y, -e);
    col = mix(vec3(0.12, 0.03, 0.2), col, smoothstep(0.0, 3.0, -e));   // lid line
    return vec4(col, inside);
}

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 p = px - center;
    float d = length(p);
    vec2 dir = p / max(d, 1.0);
    float a = atan(p.y, p.x);
    float fall = exp(-d / max(reach, 1.0));

    // ── Shinra Tensei shockwave ──
    float live = step(0.001, wave) * (1.0 - wave);
    float wr = wave * length(res) * 0.85;
    float band = exp(-pow((d - wr) / 150.0, 2.0)) * live;
    float swept = (1.0 - smoothstep(wr - 260.0, wr + 30.0, d)) * live;

    // sample nearer the centre = content pushed outward; pull = the opposite
    float s = 1.0 - 0.22 * swept + pull * 0.4 * fall + charge * 0.07 * fall;
    vec2 sp = p * s - dir * band * 140.0;
    sp += shake * vec2(sin(time * 83.0), cos(time * 71.0));

    float ca = band * 9.0 + pull * fall * 6.0;
    vec2 uv = (center + sp) / res;
    vec2 cad = dir * ca / res;
    vec3 col = vec3(texture(source, clamp(uv - cad, 0.001, 0.999)).r,
                    texture(source, clamp(uv, 0.001, 0.999)).g,
                    texture(source, clamp(uv + cad, 0.001, 0.999)).b);

    // grey-violet palette while the technique is active
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 pal = vec3(0.60, 0.55, 0.78) * (0.15 + lum * 1.2);
    col = mix(col, pal, clamp(max(charge, max(eye, pull)) * 0.55, 0.0, 0.6));
    col *= 1.0 - 0.8 * max(charge, eye * 0.6);   // the world goes dark around the eyes

    // shockwave ring + dust kicked up behind it
    // bright, slightly broken shock ring
    col += vec3(0.86, 0.80, 1.0) * band * (0.55 + 0.5 * noise(vec2(a * 18.0, time))) * 0.95;
    // radial speed lines streaming out behind the front
    float lines = pow(noise(vec2(a * 70.0, floor(time * 12.0))), 5.0);
    float behind = smoothstep(wr - 520.0, wr - 40.0, d) * (1.0 - smoothstep(wr - 40.0, wr + 10.0, d));
    col += vec3(0.82, 0.76, 1.0) * lines * behind * live * 1.6;
    float dust = fbm(vec2(a * 7.0, d * 0.012 - time * 1.5)) * smoothstep(wr - 360.0, wr, d) * swept;
    col = mix(col, vec3(0.42, 0.38, 0.44), dust * 0.55);

    // Bansho Ten'in chakra streaks rushing inwards
    float st = pow(noise(vec2(a * 48.0 / TAU * 6.0, d * 0.018 + time * 7.0)), 9.0) * 3.0;
    st *= pull * smoothstep(radius * 0.4, reach * 0.4, d) * (1.0 - smoothstep(reach * 1.5, reach * 3.5, d));
    col += vec3(0.65, 0.45, 1.0) * st * 0.6;

    col += vec3(0.85, 0.8, 1.0) * flash * 0.7;

    // ── Two Rinnegan eyes ──
    if (eye > 0.001) {
        float open = smoothstep(0.0, 1.0, eye);
        float gL, gR;
        vec4 L = rinneganEye(px, eyeL, 0.16, open, gL);
        vec4 Rr = rinneganEye(px, eyeR, -0.16, open, gR);
        col += vec3(0.55, 0.28, 1.0) * (gL + gR) * 0.75;
        col = mix(col, L.rgb, L.a);
        col = mix(col, Rr.rgb, Rr.a);
    }

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
