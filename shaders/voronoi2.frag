#version 330 core

layout(location = 0) out vec4 color;

uniform vec3 iResolution;
uniform float iTime;
uniform vec3[10] iPaletteAccentsRgb;
uniform uint iPaletteAccentsSize;
uniform vec3 iPaletteBgRgb;
uniform uint iPaletteIsDark;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    mainImage(color, gl_FragCoord.xy);
}

// Mellow riff on ZnW's Voronoi Wave, https://www.shadertoy.com/view/3lfyDB
//
const int POINTS = 16; // Point rows are determined like N / 10, from bottom to up
const float WAVE_OFFSET = 12000.0;
const float SPEED = 1.0 / 48.0;
const float COLOR_SPEED = 1.0 / 4.0;
const float BRIGHTNESS_LIGHT = 1.0;
const float BRIGHTNESS_DARK = 0.6;
const float SECONDS_PER_COLOR = 120.0;

float bezier_blend(float t)
{
    return t * t * (3.0f - 2.0f * t);
}

void voronoi(vec2 uv, inout vec3 col)
{
    vec3 voronoi = vec3(0.0);
    float time = (iTime + WAVE_OFFSET) * SPEED; // Vary time offset to affect wave pattern
    float bestDistance = 999.0;
    float lastBestDistance = bestDistance; // Used for Bloom & Outline
    for (int i = 0; i < POINTS; i++) // Is there a proper GPU implementation of voronoi out somewhere?
    {
        float fi = float(i);
        vec2 p = vec2(mod(fi, 1.0) * 0.1 + sin(fi),
                -0.05 + 0.15 * float(i / 10) + cos(fi + time * cos(uv.x * 0.025)));
        float d = distance(uv, p);
        if (d < bestDistance)
        {
            lastBestDistance = bestDistance;
            bestDistance = d;

            // Two colored gradients for voronoi color variation
            voronoi.x = p.x;
            voronoi.yz = vec2(p.x * 0.4 + p.y, p.y) * vec2(0.9, 0.87);
        }
    }
    col *= 0.68 + 0.001 * voronoi; // Mix voronoi effect and default shadertoy gradient
    col += smoothstep(0.99, 1.05, 1.0 - abs(bestDistance - lastBestDistance)) * 0.9; // Outline
    col += smoothstep(0.95, 1.01, 1.0 - abs(bestDistance - lastBestDistance)) * 0.1 * col; // Outline fade border
    col += (voronoi) * 0.1 * smoothstep(0.5, 1.0, 1.0 - abs(bestDistance - lastBestDistance)); // Bloom
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord / iResolution.xy;

    float color_idx = mod(iTime / SECONDS_PER_COLOR, iPaletteAccentsSize);
    int color_from_idx = int(floor(color_idx));
    int color_to_idx = (color_from_idx + 1) % int(iPaletteAccentsSize);
    float color_blend_process = max(0, mod(color_idx, 1) - 0.9) * 10;

    vec3 color_from = vec3(0.0, 0.0, 0.0);
    vec3 color_to = vec3(0.0, 0.0, 0.0);

    for (int i = 0; i < 10; i++) {
        if (color_from_idx == i) {
            color_from = iPaletteAccentsRgb[i];
        }
    }

    for (int i = 0; i < 10; i++) {
        if (color_to_idx == i) {
            color_to = iPaletteAccentsRgb[i];
        }
    }

    // if (uv.x > 0.95 && uv.y < 0.05) {
    //     fragColor = vec4(color_from, 1.0);
    //     return;
    // }

    // Time varying pixel color
    // vec3 col = 0.5 + 0.5 * cos(iTime * COLOR_SPEED + uv.xyx + iPaletteAccentsRgb[0]);
    // vec3 col = vec3(0.5, 0.5, 0.5);
    vec3 col = mix(color_from, color_to, bezier_blend(color_blend_process));

    // Effect looks nice on this uv scaling
    voronoi(uv * 4.0 - 1.0, col);

    float brightness = iPaletteIsDark > uint(0) ? BRIGHTNESS_DARK : BRIGHTNESS_LIGHT;

    // Output to screen
    // fragColor = vec4(mix(col, iPaletteBgRgb, BRIGHTNESS), 1.0);
    fragColor = vec4(col, 1.0) * brightness;
}
