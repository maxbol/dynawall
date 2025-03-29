#version 330 core

layout(location = 0) out vec4 col;

uniform vec3 iResolution;
uniform float iTime;
uniform float iTimeDelta;
uniform float iBatteryLevel;
uniform float iLocalTime;
uniform vec4 iMouse;
uniform vec3[10] iPaletteAccentsHsv;
uniform uint iPaletteAccentsSize;
uniform vec3 iPaletteBgRgb;
uniform uint iPaletteIsDark;

const float SECONDS_PER_COLOR = 10.0;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    mainImage(col, gl_FragCoord.xy);
}

// CC0 - Monterey wannabe
// Watching a few streams I enjoy the MacOS Monterey wallpaper
// I am a sucker for intense colors
// Here's my interpretation of the wallpaper in shader form

#define RESOLUTION          iResolution
#define TIME                iTime /6
#define PI                  3.141592654
#define TAU                 (2.0*PI)
#define ROT(a)              mat2(cos(a), sin(a), -sin(a), cos(a))

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
    return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// License: Unknown, author: Unknown, found: don't remember
vec4 alphaBlend(vec4 back, vec4 front) {
    float w = front.w + back.w * (1.0 - front.w);
    vec3 xyz = (front.xyz * front.w + back.xyz * back.w * (1.0 - front.w)) / w;
    return w > 0.0 ? vec4(xyz, w) : vec4(0.0);
}

// License: Unknown, author: Unknown, found: don't remember
vec3 alphaBlend(vec3 back, vec4 front) {
    return mix(back, front.xyz, front.w);
}

// License: Unknown, author: nmz (twitter: @stormoid), found: https://www.shadertoy.com/view/NdfyRM
float sRGB(float t) {
    return mix(1.055 * pow(t, 1. / 2.4) - 0.055, 12.92 * t, step(t, 0.0031308));
}
// License: Unknown, author: nmz (twitter: @stormoid), found: https://www.shadertoy.com/view/NdfyRM
vec3 sRGB(in vec3 c) {
    return vec3(sRGB(c.x), sRGB(c.y), sRGB(c.z));
}

// License: Unknown, author: Matt Taylor (https://github.com/64), found: https://64.github.io/tonemapping/
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0);
    v *= 0.6f;
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0f, 1.0f);
}

// License: Unknown, author: Unknown, found: don't remember
float tanh_approx(float x) {
    //  Found this somewhere on the interwebs
    //  return tanh(x);
    float x2 = x * x;
    return clamp(x * (27.0 + x2) / (27.0 + 9.0 * x2), -1.0, 1.0);
}

// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 p) {
    float a = dot(p, vec2(127.1, 311.7));
    return fract(sin(a) * 43758.5453123);
}

// License: MIT, author: Inigo Quilez, found: https://www.shadertoy.com/view/XslGRr
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i + vec2(0.0, 0.0));
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    float m0 = mix(a, b, u.x);
    float m1 = mix(c, d, u.x);
    float m2 = mix(m0, m1, u.y);

    return m2;
}

float heightFactor(vec2 p) {
    return 2.0 * smoothstep(0.0, 1.25, abs(p.x) - 0.05) + 1.0;
}

float hifbm(vec2 p) {
    float hf = heightFactor(p);
    const float aa = 0.5;
    const float pp = 2.0 - 0.;

    float sum = 0.0;
    float a = 1.0;

    for (int i = 0; i < 5; ++i) {
        sum += a * vnoise(p);
        a *= aa;
        p *= pp;
    }

    return hf * sum;
}

float lofbm(vec2 p) {
    float hf = heightFactor(p);
    const float aa = 0.5;
    const float pp = 2.0 - 0.;

    float sum = 0.0;
    float a = 1.0;

    for (int i = 0; i < 2; ++i) {
        sum += a * vnoise(p);
        a *= aa;
        p *= pp;
    }

    return hf * sum;
}

vec3 offset(float z) {
    float a = z * 0.5;
    vec2 p = vec2(0.33, 0.1) * (vec2(cos(a), sin(a * sqrt(2.0))) + vec2(cos(a * sqrt(0.75)), sin(a * sqrt(0.5))));
    //  vec2 p = vec2(0.0, 0.0);
    return vec3(p, z);
}

vec3 doffset(float z) {
    float eps = 0.1;
    return 0.5 * (offset(z + eps) - offset(z - eps)) / (2.0 * eps);
}

vec3 ddoffset(float z) {
    float eps = 0.1;
    return 0.5 * (doffset(z + eps) - doffset(z - eps)) / (2.0 * eps);
}

float hiheight(vec2 p) {
    return hifbm(p) - 1.8;
}

float loheight(vec2 p) {
    return lofbm(p) - 2.15;
}

float bezier_blend(float t)
{
    return t * t * (3.0f - 2.0f * t);
}

vec3 get_palette_hsv() {
    float color_idx = mod(iTime / SECONDS_PER_COLOR, iPaletteAccentsSize);
    int color_from_idx = int(floor(color_idx));
    int color_to_idx = (color_from_idx + 1) % int(iPaletteAccentsSize);
    float color_blend_process = max(0, mod(color_idx, 1) - 0.9) * 10;

    vec3 color_from = vec3(0.0, 0.0, 0.0);
    vec3 color_to = vec3(0.0, 0.0, 0.0);

    for (int i = 0; i < 10; i++) {
        if (color_from_idx == i) {
            color_from = iPaletteAccentsHsv[i];
        }
    }

    for (int i = 0; i < 10; i++) {
        if (color_to_idx == i) {
            color_to = iPaletteAccentsHsv[i];
        }
    }

    return mix(color_from, color_to, bezier_blend(color_blend_process));
}

vec4 plane(vec3 ro, vec3 rd, vec3 pp, vec3 npp, vec3 off, float n) {
    vec2 p = (pp - off * 2.0 * vec3(1.0, 1.0, 0.0)).xy;

    const vec2 stp = vec2(0.5, 0.33);
    float he = hiheight(vec2(p.x, pp.z) * stp);
    float lohe = loheight(vec2(p.x, pp.z) * stp);

    float d = p.y - he;
    float lod = p.y - lohe;

    float aa = distance(pp, npp) * sqrt(1.0 / 3.0);

    float df = tanh_approx(max(0.225 * distance(ro, pp) - 0.4, 0.));
    // This mix defines the range of colors of the mountains
    vec3 base_col = get_palette_hsv();
    // vec3 base_col = vec3(0.0, 0.0, 0.0);
    // vec3 base_col = iPaletteAccentsHsv[int(floor(mod(iTime, float(iPaletteAccentsSize))))];
    // vec3 base_col = iPaletteAccentsHsv[0];

    float hf = mix(base_col.x - 0.2, base_col.x + 0.2, df);
    float gf = tanh_approx(exp(-2.0 * lod));
    // float yf = smoothstep(0, -1.0, pp.y);
    float yf = smoothstep(0, -1.0, pp.y);
    // vec3 acol = hsv2rgb(vec3(hf, base_col.y, mix(base_col.z - 0.2, base_col.z + 0.2, df)));
    // vec3 gcol = hsv2rgb(vec3(hf, base_col.y, base_col.z - gf));
    // vec3 acol = hsv2rgb(vec3(hf, base_col.y, mix(0.2, base_col.z, df)));
    vec3 acol = hsv2rgb(vec3(hf, base_col.y, mix(0.2, base_col.z, df)));
    vec3 gcol = hsv2rgb(vec3(hf, base_col.y, base_col.z - gf));

    float t = smoothstep(aa, -aa, d);
    t *= mix(1.0, yf, sqrt(df));
    t = max(t, gf * yf * yf);
    vec3 col = vec3(0.0);
    col += acol;
    col += 0.5 * gcol;

    return vec4(col, t);
}

vec3 skyColor(vec3 ro, vec3 rd, vec3 nrd) {
    return iPaletteIsDark > uint(0) ? iPaletteBgRgb / 2 : iPaletteBgRgb * 2;
    // const vec3 sky = HSV2RGB(vec3(0.3, 0.2, 1.0));
    // return sky;
}

vec3 color(vec3 ww, vec3 uu, vec3 vv, vec3 ro, vec2 p) {
    vec2 np = p + 2.0 / RESOLUTION.y;
    const float rdd = 2.0;
    vec3 rd = normalize(-p.x * uu + p.y * vv + rdd * ww);
    vec3 nrd = normalize(-np.x * uu + np.y * vv + rdd * ww);

    const float planeDist = 1.0 - 0.4;
    const int furthest = 12;
    const int fadeFrom = max(furthest - 3, 0);

    const float fadeDist = planeDist * float(fadeFrom);
    const float maxDist = planeDist * float(furthest);
    float nz = floor(ro.z / planeDist);

    vec3 skyCol = skyColor(ro, rd, nrd);

    vec4 acol = vec4(0.0);
    const float cutOff = 0.995;
    bool cutOut = false;

    for (int i = 1; i <= furthest; ++i) {
        float pz = planeDist * nz + planeDist * float(i);

        float pd = (pz - ro.z) / rd.z;

        vec3 pp = ro + rd * pd;

        if (pd > 0.0 && acol.w < cutOff) {
            vec3 npp = ro + nrd * pd;

            vec3 off = offset(pp.z);

            vec4 pcol = plane(ro, rd, pp, npp, off, nz + float(i));

            float nz = pp.z - ro.z;
            float fadeIn = smoothstep(maxDist, fadeDist, pd);
            float fadeOut = smoothstep(0.0, planeDist, pd);
            pcol.w *= fadeIn;
            pcol.w *= fadeOut;

            acol = alphaBlend(pcol, acol);
        } else {
            cutOut = true;
            acol.w = acol.w > cutOff ? 1.0 : acol.w;
            break;
        }
    }

    vec3 col = alphaBlend(skyCol, acol);
    // To debug cutouts due to transparency
    //  col += cutOut ? vec3(1.0, -1.0, 0.0) : vec3(0.0);
    return col;
}

vec3 effect(vec2 p, vec2 q) {
    const mat2 rot = ROT(0.1);
    float z = TIME * 0.3333;
    vec3 ro = offset(z);
    vec3 dro = doffset(z);
    vec3 ddro = ddoffset(z);
    dro.zy *= rot;
    vec3 ww = normalize(dro);
    vec3 uu = normalize(cross(normalize(vec3(0.0, 1.0, 0.0) + 2. * ddro), ww));
    vec3 vv = cross(ww, uu);

    vec3 col = color(ww, uu, vv, ro, p);

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord / RESOLUTION.xy;
    vec2 p = -1. + 2. * q;
    p.x *= RESOLUTION.x / RESOLUTION.y;
    vec3 col = vec3(0.0);
    col = effect(p, q);
    // col += 2.0 * smoothstep(4.0, 0.0, TIME + length(p - vec2(0.0, 1.0)));
    col = aces_approx(col);
    col = sRGB(col);
    fragColor = vec4(col, 1.0);
}
