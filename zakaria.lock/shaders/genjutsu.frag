#version 440
// Itachi genjutsu (Tsukuyomi) over the lock-screen wallpaper:
//  - the world turns into red sky / black silhouettes
//  - a ripple wave + shockwave ring spreads from the avatar
//  - a giant spinning Sharingan (assets/sharingan.png) that morphs into
//    Itachi's Mangekyo Sharingan (assets/mangekyo.png)
// Compile with:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o genjutsu.frag.qsb genjutsu.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // px
    vec2 center;     // px, eye centre
    float radius;    // px, Sharingan radius
    float amount;    // 0..1 genjutsu strength
    float mangekyo;  // 0 = 3-tomoe Sharingan, 1 = Mangekyo
    float time;      // seconds
    float shock;     // 0..1 shockwave progress
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D sharTex;
layout(binding = 3) uniform sampler2D mkTex;

vec2 rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Textured eye: assets/sharingan.png (3 tomoe) cross-fading to
// assets/mangekyo.png (Itachi's Mangekyo). rgb = colour, a = coverage.
vec4 sharingan(vec2 p, float R, float t, float mk) {
    float r = length(p) / R;
    vec2 q1 = rot(p, -t * 1.8) / R;          // tomoe spin fast
    vec2 q2 = rot(p, -t * 0.9) / R;          // Mangekyo turns slower
    vec4 a = texture(sharTex, q1 * 0.5 + 0.5);
    vec4 b = texture(mkTex, q2 * 0.5 + 0.5);
    vec4 e = mix(a, b, mk) * step(r, 1.02);  // premultiplied
    vec3 col = e.rgb / max(e.a, 1e-3);
    // soft glow halo outside the disk
    float halo = exp(-max(r - 1.0, 0.0) * 6.0) * (1.0 - e.a) * 0.55;
    return vec4(mix(vec3(0.6, 0.0, 0.0) * halo, col, e.a), max(e.a, halo));
}

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 p = px - center;
    float dist = length(p);
    vec2 dir = p / max(dist, 1.0);

    // ripple
    float wave = sin(dist * 0.03 - time * 5.0) * exp(-dist / 900.0) * 9.0 * amount;
    vec3 bg = texture(source, qt_TexCoord0 + dir * wave / res).rgb;

    // Tsukuyomi palette: bright -> blood red, dark -> black
    float lum = dot(bg, vec3(0.299, 0.587, 0.114));
    vec3 tsu = vec3(0.9, 0.04, 0.06) * smoothstep(0.04, 0.55, lum) * 1.25;
    tsu += vec3(0.08, 0.0, 0.0);
    vec2 vq = (qt_TexCoord0 - 0.5) * vec2(res.x / res.y, 1.0);
    tsu *= 1.0 - 0.75 * smoothstep(0.35, 1.1, length(vq));
    vec3 col = mix(bg, tsu, amount);

    // shockwave ring
    float sr = shock * length(res) * 0.75;
    float ring = exp(-pow((dist - sr) / 26.0, 2.0)) * (1.0 - shock) * step(0.001, shock);
    col += vec3(1.0, 0.15, 0.1) * ring * 0.7;

    // giant Sharingan
    float R = radius * (0.7 + 0.3 * smoothstep(0.0, 1.0, amount));
    vec4 eye = sharingan(p, R, time, mangekyo);
    col = mix(col, eye.rgb, clamp(eye.a, 0.0, 1.0) * smoothstep(0.15, 0.85, amount));

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
