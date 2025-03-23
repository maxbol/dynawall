#version 330 core

layout(location = 0) out vec4 color;

uniform vec3 iResolution;
uniform float iTime;
uniform float iTimeDelta;
uniform float iBatteryLevel;
uniform float iLocalTime;
uniform vec4 iMouse;
uniform vec3[10] iPaletteAccentsHsv;
uniform uint iPaletteAccentsSize;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    mainImage(color, gl_FragCoord.xy);
}

/* ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * zlnimda (Nimda@zl) wrote this file.  As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return.
 * ----------------------------------------------------------------------------
 */

precision highp float;

uniform float time;
uniform vec2 touch;
uniform vec2 resolution;

float rand(vec2 co)
{
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float GetLocation(vec2 s, float d)
{
    vec2 f = s * d;

    //s = mix(vec2(0), floor(s*d),step(0.5, f));

    // tris
    f = mod(f, 8.); // because i failed somewhere

    f = f + vec2(0, 0.5) * floor(f).x;
    s = fract(f);
    f = floor(f);

    d = s.y - 0.5;
    float l = abs(d) + 0.5 * s.x;
    float ff = f.x + f.y;
    f = mix(f, f + sign(d) * vec2(0, 0.5), step(0.5, l));
    l = mix(ff, ff + sign(d) * 0.5, step(0.5, l));

    return l * rand(vec2(f));
}

vec3 hsv2rgb(float h, float s, float v)
{
    float r, g, b;
    float i = floor(h * 6);
    float f = h * 6 - i;
    float p = v * (1 - s);
    float q = v * (1 - f * s);
    float t = v * (1 - (1 - f) * s);
    int i_rem = int(mod(i, 6));

    if (i_rem == 0) {
        r = v;
        g = t;
        b = p;
    } else if (i_rem == 1) {
        r = q;
        g = v;
        b = p;
    } else if (i_rem == 2) {
        r = p;
        g = v;
        b = t;
    } else if (i_rem == 3) {
        r = p;
        g = q;
        b = v;
    } else if (i_rem == 4) {
        r = t;
        g = p;
        b = v;
    } else if (i_rem == 5) {
        r = v;
        g = p;
        b = q;
    }

    return vec3(r, g, b);

    // h = fract(h);
    // vec3 c = smoothstep(2. / 6., 1. / 6., abs(h - vec3(0.5, 2. / 6., 4. / 6.)));
    // c.r = 1. - c.r;
    // return mix(vec3(s), vec3(1.0), c) * v;
}

vec3 getRandomColor(float f, float t)
{
    float hue_p = fract(f + t);
    int color_from_idx = int(floor(hue_p * iPaletteAccentsSize));
    int color_to_idx = (color_from_idx + 1) % int(iPaletteAccentsSize);

    vec3 hsv_from = vec3(0., 0., 0.);
    vec3 hsv_to = vec3(0., 0., 0.);

    for (int i = 0; i < 10; i++) {
        if (color_from_idx == i) {
            hsv_from = iPaletteAccentsHsv[i];
        }
    }
    for (int i = 0; i < 10; i++) {
        if (color_to_idx == i) {
            hsv_to = iPaletteAccentsHsv[i];
        }
    }
    vec3 rgb_from = hsv2rgb(hsv_from.x, hsv_from.y, hsv_from.z);
    vec3 rgb_to = hsv2rgb(hsv_to.x, hsv_to.y, hsv_to.z);

    return mix(rgb_from, rgb_to, 0.2 + cos(sin(f) * 0.3));

    // return hsv2rgb(hsv_from.x, 0.2 + cos(sin(f)), 0.9);
    // return hsv2rgb(f + t, 0.2 + cos(sin(f)) * 0.3, 0.9);

    // vec3 hsv_blend = mix(hsv_from, hsv_to, hue_p);
    //
    // return hsv2rgb(hsv_blend.x, hsv_blend.y, hsv_blend.z);
    // return hsv2rgb(hsv.x, 0.2 + cos(sin(f)) * 0.3, 0.9);
    // return hsv2rgb(hsv.x, hsv.y, hsv.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float mx = max(iResolution.x, iResolution.y);
    float t = iTime * 0.1;
    vec2 s = fragCoord.xy / mx + vec2(t, 0) * 0.2;

    float f[3];
    f[0] = GetLocation(s, 12.);
    f[1] = GetLocation(s, 6.);
    f[2] = GetLocation(s, 3.);

    vec3 color = getRandomColor(f[1] * 0.05 + 0.01 * f[0] + 0.9 * f[2], t);

    fragColor = vec4(color, 1.);
}
