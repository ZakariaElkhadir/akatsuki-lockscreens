#version 440
// Obito's Kamui over the lock-screen wallpaper:
//  - space twists into a spiral vortex around `center` and is sucked inwards
//  - dark spiral tendrils sweep around the eye (like the anime warp)
//  - the world drains to Kamui's cold teal-grey
//  - Obito's Mangekyo Sharingan (assets/sharingan.png) spins at the core
// Compile with:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o kamui.frag.qsb kamui.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // px
    vec2 center;     // px, vortex centre
    float radius;    // px, Sharingan radius
    float reach;     // px, vortex falloff
    float amount;    // 0..1 vortex strength
    float eye;       // 0..1 Sharingan visibility
    float time;      // seconds since the cast
    float spin;      // rad, Sharingan rotation
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D eyeTex;

vec2 rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 p = px - center;
    float d = length(p);
    float a = atan(p.y, p.x);
    float fall = exp(-d / max(reach, 1.0));

    // ── Twist + suck: sample further out and rotated, so the scene spirals in ──
    float twist = amount * fall * (3.2 + 2.2 * time);
    vec2 sp = rot(p, twist) * (1.0 + amount * 1.4 * fall);
    vec2 uv = (center + sp) / res;
    vec3 col = texture(source, clamp(uv, vec2(0.001), vec2(0.999))).rgb;

    // ── Kamui palette: drain to cold teal-grey ──
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 kam = vec3(0.30, 0.46, 0.44) * (0.25 + lum * 1.25);
    col = mix(col, kam, amount * (0.35 + 0.5 * fall));

    // ── Dark spiral tendrils sweeping around the eye ──
    float ld = log(max(d, 1.0) / max(reach, 1.0));
    float phase = 3.0 * (a - time * 2.6) + 3.4 * ld;
    float f = sin(phase);
    float tendril = smoothstep(0.3, 0.8, f);
    float rim = smoothstep(0.25, 0.45, f) * (1.0 - tendril);     // pale edge of each arm
    float band = smoothstep(radius * 0.7, radius * 1.4, d) * (1.0 - smoothstep(reach * 2.0, reach * 4.5, d));
    float ta = amount * band;
    col = mix(col, col + vec3(0.10, 0.16, 0.16), rim * ta * 0.6);
    col = mix(col, vec3(0.03, 0.045, 0.07), tendril * ta * 0.97);

    // Darkness drawn into the core + vignette.
    col *= 1.0 - amount * 0.75 * (1.0 - smoothstep(radius * 0.8, radius * 2.2, d));
    vec2 vq = (qt_TexCoord0 - 0.5) * vec2(res.x / res.y, 1.0);
    col *= 1.0 - amount * 0.55 * smoothstep(0.3, 1.0, length(vq));

    // ── Mangekyo Sharingan at the core ──
    float R = radius * (0.35 + 0.65 * smoothstep(0.0, 1.0, eye));
    if (eye > 0.001) {
        // red halo
        float halo = exp(-max(d - R, 0.0) / (R * 0.35)) * step(R, d);
        col += vec3(0.75, 0.04, 0.02) * halo * 0.55 * eye;
        if (d < R * 1.02) {
            vec2 q = rot(p, -spin) / R;            // -1..1 inside the eye
            vec4 e = texture(eyeTex, q * 0.5 + 0.5);
            float edge = 1.0 - smoothstep(R - 1.5, R, d);
            col = mix(col, e.rgb / max(e.a, 1e-3), e.a * edge * smoothstep(0.0, 0.6, eye));
        }
    }

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
