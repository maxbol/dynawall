#version 330 core

out vec4 color;

uniform float iGlobalTime;
uniform vec3[10] iPaletteAccents;
uniform uint iPaletteAccentsSize;

const float SECONDS_PER_COLOR = 1.0;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    mainImage(color, gl_FragCoord.xy);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int color_idx = int(floor(mod(iGlobalTime, SECONDS_PER_COLOR * iPaletteAccentsSize)));
    vec3 color = vec3(0.0, 0.0, 0.0);

    for (int i = 0; i < 10; i++)
        if (color_idx == i)
            color = iPaletteAccents[i];

    // fragColor = vec4(1.0, 0.0, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
