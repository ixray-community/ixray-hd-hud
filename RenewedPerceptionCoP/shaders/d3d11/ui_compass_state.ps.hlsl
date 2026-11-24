#include "common.hlsli"

float CompassHash(float2 P)
{
    return frac(sin(dot(P, float2(12.9898f, 78.233f))) * 43758.5453f);
}

float CompassNoise(float2 P)
{
    float2 Cell = floor(P);
    float2 Fraction = frac(P);
    Fraction = Fraction * Fraction * (3.0f - 2.0f * Fraction);
    float Bottom = lerp(CompassHash(Cell), CompassHash(Cell + float2(1.0f, 0.0f)), Fraction.x);
    float Top = lerp(CompassHash(Cell + float2(0.0f, 1.0f)), CompassHash(Cell + float2(1.0f, 1.0f)), Fraction.x);
    return lerp(Bottom, Top, Fraction.y);
}

float4 main(p_TL I) : SV_Target
{
    float2 Uv = I.Tex0;
    float Level = I.Color.a;
    float Time = timers.x;

    float Anomaly = saturate(1.0f - abs(Level - 0.5f) * 8.0f);
    float Radiation = saturate(1.0f - abs(Level - 0.75f) * 8.0f);
    float Emission = saturate((Level - 0.875f) * 8.0f);

    float Wave = sin(Uv.x * 18.0f + Time * 2.5f) * 0.035f * Anomaly
               + sin(Uv.x * 31.0f - Time * 7.0f) * 0.05f * Emission;
    float Haze = (CompassNoise(float2(Uv.x * 40.0f, Time * 3.0f)) - 0.5f) * 0.08f * Radiation;
    float Offset = Uv.y - 0.5f - Wave - Haze;

    float Core = exp(-pow(Offset * 28.0f, 2.0f));
    float Glow = exp(-pow(Offset * 7.0f, 2.0f)) * 0.45f;

    float Pulse = 1.0f
                + Anomaly * 0.25f * sin(Time * 3.5f)
                + Radiation * 0.2f * sin(Time * 1.6f)
                + Emission * 0.45f * sin(Time * 6.0f);
    float Flicker = 1.0f - Radiation * 0.35f * step(0.8f, CompassNoise(float2(Time * 9.0f, 0.0f)));

    float ImpulseX = frac(Time * 0.3f) * 1.4f - 0.2f;
    float Impulse = Anomaly * exp(-pow((Uv.x - ImpulseX) * 20.0f, 2.0f));
    float Flash = Emission * pow(saturate(sin(Time * 1.7f) * sin(Time * 2.9f + 1.3f)), 6.0f) * 1.5f;

    float Edge = smoothstep(0.0f, 0.12f, Uv.x) * smoothstep(1.0f, 0.88f, Uv.x);
    float Intensity = (Core + Glow * (1.0f + Emission)) * Pulse * Flicker + (Impulse * 2.0f + Flash) * Glow;

    float3 Color = I.Color.rgb * (1.0f + Core * 0.6f);
    return float4(Color, saturate(Intensity) * Edge);
}
