#ifndef pda_glass_h_ixray_included
#define pda_glass_h_ixray_included

#include "metalic_roughness_light.hlsli"
#include "metalic_roughness_ambient.hlsli"

// Smooth forward glass: soft IBL + soft sun, no HF roughness / micro-N fireflies.
static const float kPdaGlassRoughness = 0.22f;
static const float kPdaDirtRoughness = 0.38f;
static const float kPdaMinRoughness = 0.20f;
static const float kPdaGlassAlbedo = 0.010f;
static const float kPdaDirtAlbedo = 0.08f;
static const float kPdaDielectricF0 = 0.045f;
static const float kPdaEmissiveScale = 1.0f;
static const float kPdaDirtEmissiveBlock = 0.18f;
static const float kPdaGlassBlend = 0.42f;
static const float kPdaContentProtect = 0.28f;
static const float kPdaSunSoft = 0.12f;
static const float kPdaSunSoftPow = 12.0f;
static const float kPdaVignette = 0.035f;
static const float kPdaEdgeStart = 0.60f;
static const float kPdaEdgeEnd = 0.97f;
static const float kPdaEdgeGlassBoost = 1.35f;
static const float kPdaEdgeFresnelBoost = 0.08f;
static const float kPdaGlassClamp = 1.25f;

struct PdaGlassSurface
{
	float3 Albedo;
	float Roughness;
	float Dirt;
	float3 Normal;
};

float PdaHash(float2 p)
{
	return frac(sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453f);
}

float PdaNoise(float2 uv)
{
	float2 i = floor(uv);
	float2 f = frac(uv);
	f = f * f * (3.0f - 2.0f * f);

	float a = PdaHash(i);
	float b = PdaHash(i + float2(1.0f, 0.0f));
	float c = PdaHash(i + float2(0.0f, 1.0f));
	float d = PdaHash(i + float2(1.0f, 1.0f));

	return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

float PdaEdgeMask(float2 uv)
{
	float2 c = abs(uv - 0.5f) * 2.0f;
	float rim = max(length(c), max(c.x, c.y));
	return smoothstep(kPdaEdgeStart, kPdaEdgeEnd, rim);
}

// Low-frequency dirt only. No scratch peaks (those caused the white sparkle).
float PdaDirtMask(float2 uv)
{
	float large = PdaNoise(uv * 3.5f + 8.0f);
	float mid = PdaNoise(uv * 7.0f + 2.4f);
	float dirt = saturate(large * 0.65f + mid * 0.45f - 0.38f);
	return dirt * dirt;
}

PdaGlassSurface PdaBuildSurface(float2 uv, float3 Ngeom)
{
	float dirt = PdaDirtMask(uv);

	float roughness = lerp(kPdaGlassRoughness, kPdaDirtRoughness, dirt);
	roughness = max(roughness, kPdaMinRoughness);

	float3 albedo = lerp(
		float3(kPdaGlassAlbedo, kPdaGlassAlbedo, kPdaGlassAlbedo),
		float3(kPdaDirtAlbedo, kPdaDirtAlbedo * 0.92f, kPdaDirtAlbedo * 0.84f),
		dirt);

	PdaGlassSurface S;
	S.Albedo = albedo;
	S.Roughness = roughness;
	S.Dirt = dirt;
	// Geometric normal only: micro-N + GGX = fireflies on HUD mesh.
	S.Normal = normalize(Ngeom);
	return S;
}

float3 PdaSoftSunSpec(float3 View, float3 N, float Roughness)
{
	float3 LightDir = normalize(mul((float3x3)m_V, L_sun_dir_w.xyz));
	float3 H = normalize(-View + (-LightDir));
	float NdotH = saturate(dot(N, H));
	float NdotL = saturate(dot(N, -LightDir));

	// Soft lobe instead of GGX peak: stable under hand sway.
	float soft = pow(NdotH, kPdaSunSoftPow * rcp(max(0.18f, Roughness)));
	soft *= NdotL;
	soft *= kPdaSunSoft * rcp(max(0.20f, Roughness));

	return GammaToLinear(L_sun_color.xyz) * soft;
}

float3 PdaEvalGlassPbr(float3 viewPos, PdaGlassSurface S, float hemi, float sun)
{
	float viewLen = length(viewPos);
	float3 View = viewPos * rcp(max(EPS_S, viewLen));

#ifndef USE_LEGACY_LIGHT
	float3 Diffuse = S.Albedo;
	float3 Specular = float3(kPdaDielectricF0, kPdaDielectricF0, kPdaDielectricF0);

	// Ambient/IBL only for environment glass. Soft sun lobe separately.
	float3 Ambient = GammaToLinear(saturate(hemi))
		* AmbientLighting(View, S.Normal, Diffuse, Specular, S.Roughness, saturate(hemi));

	float3 SoftSun = PdaSoftSunSpec(View, S.Normal, S.Roughness) * saturate(sun);

	float3 glass = Ambient + SoftSun;
#else
	float gloss = 1.0f - S.Roughness;
	float material = 0.0f;

	float3 Ambient = AmbientLightingLegcay(View, S.Normal, S.Albedo, material, gloss, saturate(hemi));
	float3 SoftSun = PdaSoftSunSpec(View, S.Normal, S.Roughness) * saturate(sun);
	float3 glass = Ambient + SoftSun;
#endif

	// Kill residual fireflies from env mip aliasing.
	glass = min(glass, float3(kPdaGlassClamp, kPdaGlassClamp, kPdaGlassClamp));
	return glass;
}

float3 PdaGlassLcd(float3 lcdGamma, float2 uv)
{
	float2 c = (uv - 0.5f) * 2.0f;
	float vig = 1.0f - saturate(dot(c, c)) * kPdaVignette;
	return saturate(lcdGamma * vig);
}

float3 PdaGlassCompose(
	float3 lcdGamma,
	float2 uv,
	float3 Ngeom,
	float3 viewPos,
	float glassFade,
	float hemi,
	float sun)
{
	if (glassFade <= 0.001f)
	{
		return PdaGlassLcd(lcdGamma, uv);
	}

	float edge = PdaEdgeMask(uv);
	PdaGlassSurface S = PdaBuildSurface(uv, Ngeom);

	float dirtBlock = lerp(1.0f, 1.0f - kPdaDirtEmissiveBlock, S.Dirt);
	float3 lcd = PdaGlassLcd(lcdGamma, uv);
	float3 emissive = GammaToLinear(lcd) * kPdaEmissiveScale * dirtBlock;

	float3 glassLin = PdaEvalGlassPbr(viewPos, S, hemi, sun);

	float viewLen = length(viewPos);
	float3 View = viewPos * rcp(max(EPS_S, viewLen));
	float NdotV = saturate(dot(S.Normal, -View));
	float fresnel = kPdaDielectricF0 + (1.0f - kPdaDielectricF0) * pow(1.0f - NdotV, 5.0f);
	fresnel = saturate(fresnel + edge * kPdaEdgeFresnelBoost);

	float blend = kPdaGlassBlend * glassFade * lerp(1.0f, kPdaEdgeGlassBoost, edge);
	blend *= fresnel;

	float luma = dot(emissive, float3(0.299f, 0.587f, 0.114f));
	float protect = lerp(0.80f, kPdaContentProtect, saturate(luma * 1.55f));
	protect = lerp(protect, protect * 0.88f, edge * 0.30f);

	float3 outLin = emissive + glassLin * blend * protect;
	outLin = max(outLin, emissive);
	outLin *= rcp(1.0f + outLin * 0.22f);
	outLin = saturate(outLin);

	return LinearToGamma(outLin);
}

#endif
