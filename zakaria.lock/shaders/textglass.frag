#version 440
// Liquid glass for arbitrary shapes (text). Same lighting model as
// liquidglass.frag, but the bevel height field comes from a blurred copy of
// the shape's alpha instead of a rounded-rect SDF.
// Compile with: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o textglass.frag.qsb textglass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // effect px
    vec2 res;           // backdrop px
    vec2 origin;        // effect top-left in backdrop px
    float bevel;        // bevel depth px
    float refraction;
    float chroma;
    float edgeHL;
    float spec;
    float fresnel;
    float brightness;
    float shadowAlpha;
    float shadowOffY;
    vec4 tintColor;
};

layout(binding = 1) uniform sampler2D sharpTex;
layout(binding = 2) uniform sampler2D blurTex;
layout(binding = 3) uniform sampler2D maskTex;
layout(binding = 4) uniform sampler2D heightTex;

float H(vec2 uv) { return texture(heightTex, uv).a; }

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 texel = vec2(1.0) / itemSize;
    float m = texture(maskTex, uv).a;

    // Shadow from the blurred shape, offset downwards
    if (m < 0.01) {
        float s = H(uv - vec2(0.0, shadowOffY) * texel);
        float a = s * s * shadowAlpha * qt_Opacity;
        fragColor = vec4(0.0, 0.0, 0.0, a);
        return;
    }

    float h = H(uv);
    float e = 1.5;
    vec2 hGrad = vec2(H(uv + vec2(e, 0.0) * texel) - H(uv - vec2(e, 0.0) * texel),
                      H(uv + vec2(0.0, e) * texel) - H(uv - vec2(0.0, e) * texel))
                 * bevel / (2.0 * e);
    vec3 N = normalize(vec3(-hGrad, 1.0));

    float depth = smoothstep(0.45, 1.0, h);
    float edge = 1.0 - depth;

    // Biconvex refraction, as in liquidglass
    vec2 pxToUV = vec2(1.0) / res;
    float refrPow = 1.0 - 1.0 / 1.5;
    vec2 surf = hGrad * refrPow;
    vec2 refrPx = (surf * 2.0 + surf * h * 0.5) * refraction * 30.0;
    vec2 screenUV = (origin + uv * itemSize) / res;
    vec2 base = screenUV + refrPx * pxToUV;

    float caS = chroma * 18.0 * (edge * 0.7 + 0.3) * 2.0;
    vec2 caD = N.xy * caS * pxToUV;
    vec3 sharp = vec3(texture(sharpTex, base + caD).r,
                      texture(sharpTex, base).g,
                      texture(sharpTex, base - caD).b);
    vec3 blur = vec3(texture(blurTex, base + caD).r,
                     texture(blurTex, base).g,
                     texture(blurTex, base - caD).b);
    vec3 col = mix(sharp, blur, 1.0 - edge * 0.15);

    col *= 1.0 + brightness;
    col *= 1.0 + 0.06 * depth;
    col = mix(col, tintColor.rgb, tintColor.a);

    float fres = pow(1.0 - abs(N.z), 4.0) * fresnel;

    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 H1 = normalize(normalize(vec3(0.4, 0.7, 1.0)) + V);
    float sp1 = pow(max(dot(N, H1), 0.0), 90.0);
    vec3 H2 = normalize(normalize(vec3(-0.3, -0.5, 1.0)) + V);
    float sp2 = pow(max(dot(N, H2), 0.0), 50.0) * 0.3;
    float spB = pow(max(dot(N, normalize(vec3(0.1, 0.3, 1.0))), 0.0), 6.0) * 0.1;
    vec3 H4 = normalize(normalize(vec3(0.0, 0.9, 0.4)) + V);
    float sp4 = pow(max(dot(N, H4), 0.0), 120.0) * 0.6;
    float totalSpec = (sp1 + sp2 + spB + sp4) * spec;

    // Rim: the outer band of the shape, lit from the top
    float innerStroke = 1.0 - smoothstep(0.5, 0.62, h);
    innerStroke *= 0.4 + 0.6 * clamp(0.5 - N.y * 2.0, 0.0, 1.0);

    float rim = edge * edgeHL * 0.22;
    float envRefl = (N.y * 0.5 + 0.5) * fres * 0.08;

    vec3 fin = col + vec3(totalSpec + rim + innerStroke * edgeHL * 0.55 + envRefl);
    fin = mix(fin, vec3(1.0), fres * 0.2);

    float a = m * qt_Opacity;
    fragColor = vec4(fin * a, a);
}
