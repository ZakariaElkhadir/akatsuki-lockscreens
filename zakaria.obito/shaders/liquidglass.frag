#version 440
// Faithful port of ybouane/liquidglass FS_GLASS (src/shaders.ts) to Qt RHI:
// pill-bevel height field, biconvex dual-surface refraction, chromatic
// dispersion, edge-weighted blur mix, Fresnel, multi-light Blinn-Phong
// specular, inner stroke + rim glow, offset drop shadow.
// Additions: a mirror term that reflects the surroundings into the bevel,
// a cursor-following key light, and support for an elastic scale/translate.
// Coordinates are y-down. Compile with:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o liquidglass.frag.qsb liquidglass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;     // unscaled panel px
    vec2 res;           // backdrop px
    vec2 origin;        // transformed panel top-left in backdrop px
    vec2 scl;           // elastic stretch
    vec2 light;         // cursor direction from the panel centre (-1..1), 0 = none
    float pad;          // shadow padding px
    float radius;
    float refraction;
    float chroma;
    float edgeHL;
    float spec;
    float fresnel;
    float zRadius;
    float brightness;
    float sat;
    float blurMix;
    float mirror;
    float shadowAlpha;
    float shadowSpread;
    float shadowOffY;
    float bevel;        // 1 = 3D pill bevel rim, 0 = flat pane
    vec4 tintColor;     // rgb + mix amount
};

layout(binding = 1) uniform sampler2D sharpTex;
layout(binding = 2) uniform sampler2D blurTex;

float rrSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float bevelHeight(float d, float zR) {
    if (d <= 0.0) return 0.0;
    if (d >= zR) return zR;
    return sqrt(d * (2.0 * zR - d));
}

void main() {
    vec2 total = panelSize + vec2(pad * 2.0);
    vec2 half_ = panelSize * 0.5;
    vec2 localPx = qt_TexCoord0 * total - vec2(pad) - half_;   // px from centre, y-down
    vec2 screenUV = (origin + (localPx + half_) * scl) / res;
    vec2 pxToUV = scl / res;

    float r = min(radius, min(half_.x, half_.y));
    float sdf = rrSDF(localPx, half_, r);

    // ── Shadow ──
    if (sdf > 0.0) {
        float sdfShadow = rrSDF(localPx - vec2(0.0, shadowOffY), half_, r);
        float d = max(sdfShadow - 1.0, 0.0);
        float spread = max(shadowSpread, 1.0);
        float outerShadow = exp(-d * d / (spread * spread)) * 0.65;
        float contactShadow = exp(-d * 0.08 / max(spread * 0.04, 0.01)) * 0.35;
        fragColor = vec4(0.0, 0.0, 0.0, (outerShadow + contactShadow) * shadowAlpha * qt_Opacity);
        return;
    }

    float mask = 1.0 - smoothstep(-1.5, 0.5, sdf);
    float maxD = min(half_.x, half_.y);
    float inside = -sdf;
    float edge = smoothstep(maxD * 0.35, 0.0, inside);

    // ── Surface normal from the pill bevel ──
    float zR = zRadius;
    float e = 2.0;
    float hC = bevelHeight(inside, zR);
    float hR = bevelHeight(-rrSDF(localPx + vec2(e, 0.0), half_, r), zR);
    float hL = bevelHeight(-rrSDF(localPx - vec2(e, 0.0), half_, r), zR);
    float hU = bevelHeight(-rrSDF(localPx + vec2(0.0, e), half_, r), zR);
    float hD = bevelHeight(-rrSDF(localPx - vec2(0.0, e), half_, r), zR);
    vec2 hGrad = vec2(hR - hL, hU - hD) / (2.0 * e) * bevel;
    vec3 N = normalize(vec3(-hGrad, 1.0));
    float depth = mix(1.0, smoothstep(0.0, zR, inside), bevel);
    edge *= bevel;

    // ── Biconvex refraction ──
    float refrPow = 1.0 - 1.0 / 1.5;
    float thickNorm = (hC * 2.0) / max(zR * 2.0, 1.0);
    vec2 surf = hGrad * refrPow;
    vec2 refrPx = (surf + surf + surf * thickNorm * 0.5) * refraction * 30.0;
    refrPx += (-localPx / max(half_, vec2(1.0))) * refraction * 4.0 * depth;
    vec2 base = screenUV + refrPx * pxToUV;

    // ── Chromatic aberration ──
    float caS = chroma * 18.0 * (edge * 0.7 + 0.3) * 2.0;
    vec2 caD = N.xy * caS * pxToUV;
    vec3 sharp = vec3(texture(sharpTex, base + caD).r,
                      texture(sharpTex, base).g,
                      texture(sharpTex, base - caD).b);
    vec3 blur = vec3(texture(blurTex, base + caD).r,
                     texture(blurTex, base).g,
                     texture(blurTex, base - caD).b);
    // Clear at the rim, optional softening in the middle.
    vec3 col = mix(sharp, blur, blurMix * (1.0 - edge * 0.15));

    col *= 1.0 + brightness;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(lum), col, 1.0 + sat);
    col *= 1.0 + 0.06 * depth;
    col = mix(col, tintColor.rgb, tintColor.a);

    // ── Fresnel + mirror: the steep bevel reflects what surrounds the panel ──
    float fres = pow(1.0 - abs(N.z), 4.0) * fresnel;
    float grazing = 1.0 - N.z;                                   // 0 flat, ->1 at the rim
    vec2 mirrorPx = N.xy * (zR * 1.6 + 24.0) * grazing;          // look outward past the edge
    vec3 env = texture(sharpTex, screenUV + mirrorPx * pxToUV).rgb;
    float mirrorAmt = clamp(mirror * (fres * 0.9 + grazing * 0.35), 0.0, 0.85);
    col = mix(col, env * 1.15 + 0.04, mirrorAmt);

    // ── Multi-light Blinn-Phong ──
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 H1 = normalize(normalize(vec3(0.4, 0.7, 1.0)) + V);
    float sp1 = pow(max(dot(N, H1), 0.0), 90.0);
    vec3 H2 = normalize(normalize(vec3(-0.3, -0.5, 1.0)) + V);
    float sp2 = pow(max(dot(N, H2), 0.0), 50.0) * 0.3;
    float spB = pow(max(dot(N, normalize(vec3(0.1, 0.3, 1.0))), 0.0), 6.0) * 0.1;
    vec3 H4 = normalize(normalize(vec3(0.0, 0.9, 0.4)) + V);
    float sp4 = pow(max(dot(N, H4), 0.0), 120.0) * 0.6;
    // Key light that follows the cursor (default: top-left).
    vec2 ld = length(light) > 0.001 ? normalize(light) : vec2(-0.55, -0.85);
    vec3 H5 = normalize(normalize(vec3(ld * 0.9, 0.45)) + V);
    float sp5 = pow(max(dot(N, H5), 0.0), 60.0) * 0.9;
    float totalSpec = (sp1 + sp2 + spB + sp4 + sp5) * spec;

    // ── Inner stroke, rim, glow ──
    float bw = 1.5;
    float innerStroke = smoothstep(-bw - 1.0, -bw, sdf) * (1.0 - smoothstep(-1.0, 0.0, sdf));
    float facing = 0.5 + 0.5 * dot(normalize(localPx / max(half_, vec2(1.0)) + 1e-4), ld);
    innerStroke *= 0.35 + 0.65 * facing;
    innerStroke *= bevel;
    float rim = edge * edgeHL * 0.22;
    float innerGlow = smoothstep(5.0, 0.0, -sdf) * edgeHL * 0.15 * bevel;
    float envRefl = (N.y * 0.5 + 0.5) * fres * 0.08;

    vec3 fin = col + vec3(totalSpec + rim + innerGlow + innerStroke * edgeHL * 0.55 + envRefl);
    fin = mix(fin, vec3(1.0), fres * 0.2);

    float a = mask * qt_Opacity;
    fragColor = vec4(fin * a, a);
}
