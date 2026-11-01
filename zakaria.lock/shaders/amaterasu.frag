#version 440
// Amaterasu: black flames burning around a rounded rectangle (the login card).
// Tall tongues rise off the top edge, shorter ones climb the sides, with
// dark crimson/violet fringes, a faint glow and rising embers.
// Compile with:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o amaterasu.frag.qsb amaterasu.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;       // item px
    vec4 card;       // x, y, w, h of the burning rect inside the item
    float radius;
    float time;
    float amount;    // 0..1 fire strength
    float uiScale;   // ui scale
};

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
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

float rrSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 half_ = card.zw * 0.5;
    vec2 lp = px - (card.xy + half_);
    float r = min(radius, min(half_.x, half_.y));
    float sdf = rrSDF(lp, half_, r);

    // Flames are tall above the card and short below it.
    float up = clamp(0.5 - lp.y / (2.0 * half_.y), 0.0, 1.0);
    float H = (16.0 + 150.0 * pow(up, 1.6)) * uiScale * (0.35 + 0.65 * amount);
    // Above the top edge, measure height straight up so tongues stand vertical.
    float d = sdf >= 0.0 ? sdf : -sdf * 3.0;

    // Domain-warped fbm scrolling upwards (y-down, so +time moves features up).
    // Stretched vertically so the noise forms tall licking tongues.
    vec2 q = vec2(px.x * 0.026, px.y * 0.0075) / uiScale;
    float w = fbm(q * 0.8 + vec2(0.0, time * 1.1));
    float n = fbm(q * 1.7 + vec2(w * 1.6 - time * 0.2, time * 1.9));
    n = pow(n, 1.35) * 1.25;
    float v = n * 1.45 - d / max(H, 1.0) - (1.0 - amount) * 0.75 - 0.12;

    float body = smoothstep(0.0, 0.1, v);
    float core = smoothstep(0.12, 0.42, v);
    vec3 fringe = mix(vec3(0.55, 0.02, 0.10), vec3(0.32, 0.02, 0.30), n);
    vec3 col = mix(fringe, vec3(0.008, 0.0, 0.012), core);
    float a = body;

    // Faint smouldering glow just outside the flames.
    float glow = smoothstep(-0.18, 0.0, v) * (1.0 - body) * 0.35 * amount;
    col = mix(vec3(0.45, 0.03, 0.18), col, a / max(a + glow, 1e-4));
    a = a + glow * (1.0 - a);

    // Rising embers above the card.
    vec2 g = vec2(px.x / (34.0 * uiScale), (px.y + time * 110.0 * uiScale) / (34.0 * uiScale));
    vec2 cell = floor(g);
    float h = hash(cell);
    if (h > 0.78 && sdf > 0.0 && lp.y < half_.y * 0.3) {
        vec2 sp = vec2(hash(cell + 7.1), hash(cell + 3.3)) * 0.8 + 0.1;
        sp.x += 0.15 * sin(time * 3.0 + h * 40.0);
        float e = length((fract(g) - sp) * 34.0 * uiScale);
        float life = 1.0 - smoothstep(0.0, 260.0 * uiScale, sdf);
        float ember = (1.0 - smoothstep(0.8 * uiScale, 2.6 * uiScale, e)) * life * amount;
        col = mix(col, vec3(0.8, 0.12, 0.35), ember * (1.0 - a));
        a = max(a, ember);
    }

    // Fade out before the edges of the quad so nothing looks clipped.
    vec2 e2 = min(px, size - px);
    a *= smoothstep(0.0, 60.0 * uiScale, min(e2.x, e2.y));
    a *= qt_Opacity;
    fragColor = vec4(col * a, a);
}
