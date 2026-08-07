#include "common.hlsli"
#include "pda_glass.hlsli"

uniform float4 m_affects;

Texture2D s_vp2;
Texture2D s_load;

float PdaGlitchNoise(float2 co)
{
	return frac(sin(dot(co.xy, float2(12.9898f, 78.233f))) * 43758.5453f) * 0.5f;
}

float PdaGlassFadeFromAffects()
{
	float fade = 1.0f - saturate((m_affects.x - 0.20f) * 4.0f);
	fade *= 1.0f - saturate((m_affects.x - 0.38f) * 8.0f);
	return saturate(fade);
}

float3 PdaSampleUi(float2 uv)
{
	float4 ui = (m_affects.x < 0.27f)
		? s_vp2.Sample(smp_rtlinear, uv)
		: s_base.Sample(smp_base, uv);

	float noise = PdaGlitchNoise(uv * timers.z) * m_affects.x * m_affects.x * 20.0f;
	ui.rgb += noise;

	if (m_affects.x > 0.41f)
	{
		ui.rgb = 0.0f;
	}

	return ui.rgb;
}

float2 PdaGlitchUv(float2 uv)
{
	float problems = frac(timers.z * 5.0f * (1.0f + 2.0f * m_affects.x));
	uv.x += (m_affects.x > 0.09f && uv.y > problems - 0.01f && uv.y < problems)
		? sin((uv.y - problems) * 5.0f * m_affects.y)
		: 0.0f;

	problems = cos((frac(timers.z * 2.0f) - 0.5f) * 3.1416f) * 2.0f - 0.8f;
	const float AMPL = 0.13f;
	uv.x -= (m_affects.x > 0.15f && uv.y > problems - AMPL && uv.y < problems + AMPL)
		? cos(4.71f * (uv.y - problems) / AMPL) * sin(frac(timers.z) * 6.2831f * 90.0f) * 0.02f
			* (AMPL - abs(uv.y - problems)) / AMPL
		: 0.0f;

	uv.x += (m_affects.x > 0.38f) ? (m_affects.y - 0.5f) * 0.04f : 0.0f;
	return uv;
}

float3 PdaShadeScreen(float2 uv, float3 N, float3 viewPos, float hemi, float sun, float glassFade)
{
	float3 ui = PdaSampleUi(uv);
	return PdaGlassCompose(ui, uv, N, viewPos, glassFade, hemi, sun);
}

float4 PdaProblemsMain(p_bumped_new I)
{
	float2 uv = PdaGlitchUv(I.tcdh.xy);
	float3 N = normalize(float3(I.M1.z, I.M2.z, I.M3.z));

	float hemi = saturate(I.tcdh.z);
	float sun = saturate(I.tcdh.w * 2.0f);
	float glassFade = PdaGlassFadeFromAffects();

	if (m_affects.x > 0.41f)
	{
		glassFade = 0.0f;
	}

	return float4(PdaShadeScreen(uv, N, I.position.xyz, hemi, sun, glassFade), 1.0f);
}

float4 PdaLoadingMain(p_bumped_new I)
{
	float2 uv = I.tcdh.xy;
	float3 N = normalize(float3(I.M1.z, I.M2.z, I.M3.z));
	float3 load = s_load.Sample(smp_base, uv).rgb;

	float hemi = saturate(I.tcdh.z);
	float sun = saturate(I.tcdh.w * 2.0f);

	return float4(PdaGlassCompose(load, uv, N, I.position.xyz, 0.55f, hemi, sun), 1.0f);
}

float4 main(p_bumped_new I) : SV_Target
{
	float4 final = 1.0f;

	[branch]
	if (m_affects.a > 0.0f && m_affects.x >= 0.08f)
	{
		final = PdaLoadingMain(I);
	}
	else
	{
		final = PdaProblemsMain(I);
	}

	final.xyz = detonemap(final.xyz * 0.8f);
	return final;
}
