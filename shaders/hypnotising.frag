#version 330 core

layout(location = 0) out vec4 color;

uniform float iTime;
uniform vec3 iResolution;
uniform vec3[10] iPaletteAccents;
uniform uint iPaletteAccentsSize;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    mainImage(color, gl_FragCoord.xy);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime * 1;
    float stp = t * 1.f;
    float px = (uv.x / 2.f) + (fragCoord.x * 0.1f * 0.00155f * stp);
    float py = (uv.y / 2.f) + (fragCoord.y * 0.1f * 0.00155f * stp);
    float k = mod(sin(px) + sin(py) + 2.f, (1.f + pow(stp, 2.f)));
    vec3 col = vec3(
            1.f - mod((k + t) * ((1.f) * 0.1f), 1.f),
            mod(k, 0.5f),
            1.f - mod(k, (0.25f + (t / 3.141f))));
    fragColor = vec4(col, 1.0);
}
