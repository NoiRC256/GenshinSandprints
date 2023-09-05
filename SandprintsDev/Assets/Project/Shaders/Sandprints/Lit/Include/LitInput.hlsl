#ifndef UNIVERSAL_LIT_INPUT_INCLUDED
#define UNIVERSAL_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "./Include/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _BumpMap_ST;
    float4 _EmissionMap_ST;
    float4 _SmokeNoiseTex_ST;
    float4 _SmokeMaskTex_ST;
    float4 _PathNoiseTexture_ST;
    half _NoiseInt;
    half4 _BaseColor;
    half4 _SpecColor;
    half4 _EmissionColor;
    half4 _SmokeColor;
    half _Cutoff;
    half _Smoothness;
    half _Metallic;
    half _BumpScale;
    half _OcclusionStrength;
    half _Surface;
    half _EmissionThreshold;
    half _EmissionPow;
    half4 _SmokeVector;
    half _HeightScale;
    half _PathNormalScale;
    half _DownInt;
    int _Tesselation;
    half _MaxTessDistance;
CBUFFER_END

TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_SmokeNoiseTex);      SAMPLER(sampler_SmokeNoiseTex);
TEXTURE2D(_SmokeMaskTex);       SAMPLER(sampler_SmokeMaskTex);
TEXTURE2D(_SandprintsRT);             SAMPLER(sampler_SandprintsRT);
TEXTURE2D(_PathNoiseTexture);   SAMPLER(sampler_PathNoiseTexture);
float4 _SandprintsCamPos;
float _SandprintsCamOrthoSize;

#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

    #ifdef _METALLICSPECGLOSSMAP
        specGloss = SAMPLE_METALLICSPECULAR(uv);
        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _Smoothness;
        #else
            specGloss.a *= _Smoothness;
        #endif
    #else // _METALLICSPECGLOSSMAP
        #if _SPECULAR_SETUP
            specGloss.rgb = _SpecColor.rgb;
        #else
            specGloss.rgb = _Metallic.rrr;
        #endif

        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _Smoothness;
        #else
            specGloss.a = _Smoothness;
        #endif
    #endif

    return specGloss;
}

half SampleOcclusion(float2 uv)
{
    #ifdef _OCCLUSIONMAP
        // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
        #if defined(SHADER_API_GLES)
            return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
        #else
            half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
            return LerpWhiteTo(occ, _OcclusionStrength);
        #endif
    #else
        return 1.0;
    #endif
}

inline void InitializeStandardLitSurfaceData(float2 uv, out MySurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

    #if _SPECULAR_SETUP
        outSurfaceData.metallic = 1.0h;
        outSurfaceData.specular = specGloss.rgb;
    #else
        outSurfaceData.metallic = specGloss.r;
        outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
    #endif

    outSurfaceData.smoothness = specGloss.a;
    outSurfaceData.normalTS = SampleNormal(uv * _BumpMap_ST.xy + _BumpMap_ST.zw, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv * _EmissionMap_ST.xy + _EmissionMap_ST.zw, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap), _EmissionThreshold);
}

#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED