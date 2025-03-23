#version 330 core

layout(location = 0) out vec4 color;

uniform float iTime;
uniform vec3 iResolution;
uniform vec3[10] iPaletteAccentsRgb;
uniform uint iPaletteAccentsSize;

const float SECONDS_PER_COLOR = 10.0;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    mainImage(color, gl_FragCoord.xy);
}

float bezier_blend(float t)
{
    return t * t * (3.0f - 2.0f * t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
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

    vec3 col = mix(color_from, color_to, bezier_blend(color_blend_process));

    fragColor = vec4(
            col,
            1.0
        );
}
