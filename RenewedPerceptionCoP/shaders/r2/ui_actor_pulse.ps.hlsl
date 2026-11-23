#include "common.hlsli"

struct p_ui
{
    float2 tc0 : TEXCOORD0;
    float4 color : COLOR0;
};

float4 main(p_ui I) : COLOR
{
    float2 centeredUv = (I.tc0 - 0.5f) * 2.0f;
    float radius = length(centeredUv);
    float time = timers.x;

    float phaseA = frac(time * 0.6f);
    float phaseB = frac(time * 0.6f + 0.5f);
    float ringA = 1.0f - smoothstep(0.0f, 0.12f, abs(radius - lerp(0.12f, 0.95f, phaseA)));
    float ringB = 1.0f - smoothstep(0.0f, 0.12f, abs(radius - lerp(0.12f, 0.95f, phaseB)));
    float fadeA = 1.0f - phaseA;
    float fadeB = 1.0f - phaseB;
    float pulse = ringA * fadeA * fadeA + ringB * fadeB * fadeB;

    float glow = (1.0f - smoothstep(0.0f, 0.45f, radius)) * (0.35f + 0.15f * sin(time * 3.7699112f));
    float edge = 1.0f - smoothstep(0.9f, 1.0f, radius);
    float alpha = saturate(pulse * 0.9f + glow) * edge * I.color.a;

    return float4(I.color.rgb, alpha);
}
