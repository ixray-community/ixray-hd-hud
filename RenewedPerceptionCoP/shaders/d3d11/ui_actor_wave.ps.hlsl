#include "common.hlsli"

float4 main(p_TL I) : SV_Target
{
    float mask = s_base.Sample(smp_base, I.Tex0).a;
    float2 centeredUv = (I.Tex0 - 0.5f) * 2.0f;
    float radius = length(centeredUv);
    float time = timers.x;

    float core = 1.0f - smoothstep(0.0f, 0.14f, radius);
    float innerGlow = (1.0f - smoothstep(0.08f, 0.58f, radius)) * 0.42f;

    float rings = sin((radius * 4.25f - time * 1.15f) * 6.2831853f);
    rings = saturate(rings * 0.5f + 0.5f);
    rings *= rings;
    rings *= rings;
    rings *= smoothstep(0.14f, 0.28f, radius) * (1.0f - smoothstep(0.64f, 0.92f, radius));
    rings *= 0.58f;

    float alpha = saturate(core + innerGlow + rings) * mask * I.Color.a;
    float3 beaconColor = float3(126.0f / 255.0f, 1.0f, 143.0f / 255.0f);
    float3 coreColor = lerp(beaconColor, float3(1.0f, 1.0f, 1.0f), 0.85f);
    float3 color = beaconColor * (innerGlow * 0.9f + rings * 1.1f) + coreColor * core * 1.25f;

    return float4(color * I.Color.rgb, alpha);
}
