#version 440
// Amegakure rain: three layers of slanted streaks, transparent overlay.
// The Shinra Tensei shockwave clears the rain inside its radius.
// Compile with:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o rain.frag.qsb rain.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float time;
    float uiScale;
    vec2 center;     // shockwave centre
    float wave;      // 0..1 shockwave progress (0 = none)
};

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

float layer(vec2 px, float w, float len, float speed, float thick, float seed) {
    float x = px.x + px.y * 0.18;                 // slant
    float colId = floor(x / w);
    float h = hash(colId + seed);
    float h2 = hash(colId * 1.7 + seed + 3.1);
    if (h2 < 0.35) return 0.0;                    // not every column rains
    float period = len * (3.0 + 4.0 * h);
    float y = px.y - time * speed * (0.8 + 0.5 * h) + h * 997.0;
    float seg = fract(y / period) * period;
    float drop = smoothstep(0.0, len * 0.2, seg) * (1.0 - smoothstep(len * 0.6, len, seg));
    float xc = abs(fract(x / w) - 0.5 - (h - 0.5) * 0.6) * w;
    return drop * (1.0 - smoothstep(thick * 0.5, thick, xc));
}

void main() {
    vec2 px = qt_TexCoord0 * res;
    float u = uiScale;
    float r = layer(px, 9.0 * u, 70.0 * u, 1500.0 * u, 1.6 * u, 1.0) * 0.55
            + layer(px, 14.0 * u, 110.0 * u, 2100.0 * u, 2.2 * u, 7.0) * 0.4
            + layer(px, 23.0 * u, 160.0 * u, 2800.0 * u, 3.0 * u, 13.0) * 0.3;

    if (wave > 0.001) {
        float wr = wave * length(res) * 0.85;
        r *= smoothstep(wr - 120.0, wr + 20.0, length(px - center)) + wave * wave;
    }

    float a = clamp(r, 0.0, 1.0) * 0.5 * qt_Opacity;
    fragColor = vec4(vec3(0.82, 0.84, 0.95) * a, a);
}
