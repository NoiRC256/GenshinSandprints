Shader "NekoLabs/Sandprints/Lit"
{
    Properties
    {
        [Header(Main)]
        [MainTexture] _MainTex ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" { }
        [HDR] _BaseColor ("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        [Toggle(_ALPHATEST_ON)] _AlphaTestToggle ("Alpha Clipping", Float) = 0
        _Cutoff ("Alpha Cutoff", Float) = 0.5

        [Header(Main)]
        _Noise ("Ground Noise", 2D) = "gray" { }
        _NoiseScale ("Ground Noise Scale", Range(0, 2)) = 0.1
        _NoiseWeight ("Ground Noise Weight", Range(0, 2)) = 0.1
        [HDR]_ShadowColor ("Ground Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
        
        [Space]
        [Header(Tesselation)]
        _MinTessDistance ("Min Tessellation Distance", Float) = 10
        _MaxTessDistance ("Max Tessellation Distance", Float) = 20
        _Tess ("Tessellation", Range(1, 64)) = 20
        
        [Space]
        [Header(Ground)]
        [HDR]_PathColorIn ("Indent Color In", Color) = (0.5, 0.5, 0.7, 1)
        [HDR]_PathColorOut ("Indent Color Out", Color) = (0.5, 0.5, 0.7, 1)
        [HDR]_TrailRimColor ("Indent Rim Color", Color) = (1, 1, 1, 1)
        _PathBlending ("Indent Blending", Range(0, 10)) = 0.3
        _TrailRimBlending ("Indent Rim Blending", Range(0, 10)) = 0.3


        _SnowHeight ("Ground Height", Range(0, 1)) = 0.3
        _SnowDepth ("Trail Depth", Range(0, 1)) = 1
        _TrailRimHeight ("Trail Rim Height", Range(0, 1)) = 0.3
        _SnowTextureOpacity ("Main Texture Opacity", Range(0, 2)) = 0.3
        _MainTextureScale ("Main Texture Scale", Range(0, 2)) = 0.3
        
        [Space]
        [Header(Sparkles)]
        _SparkleScale ("Sparkle Scale", Range(0, 10)) = 10
        _SparkCutoff ("Sparkle Cutoff", Range(0, 10)) = 0.8
        _SparkleNoise ("Sparkle Noise", 2D) = "gray" { }
        
        [Space]
        [Header(Rim)]
        _RimPower ("Rim Power", Range(0, 20)) = 20
        [HDR]_RimColor ("Rim Color Snow", Color) = (0.5, 0.5, 0.5, 1)

        [Header(Shadow mapping)]
        _NormalSmoothThreshold ("Normal Smooth Threshold", Float) = 0.01
        _ReceiveShadowMappingPosOffset ("Receive Shadow Offset", Float) = 0
    }

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #include "SandprintsTessellation.hlsl"

    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    // Note, v11 changes this to :
    // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
    #pragma multi_compile_fragment _ _SHADOWS_SOFT
    #pragma multi_compile _ LIGHTMAP_ON
    #pragma multi_compile _ DIRLIGHTMAP_COMBINED
    #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
    #pragma multi_compile _ SHADOWS_SHADOWMASK
    #pragma multi_compile _ _SCREEN_SPACE_OCCLUSION

    #pragma multi_compile_fog
    #pragma multi_compile_instancing

    #pragma require tessellation tessHW
    #pragma vertex TessellationVertex
    #pragma hull TessellationHull
    #pragma domain TessellationDomain
    
    ControlPoint TessellationVertex(MyAttributes v)
    {
        ControlPoint p;
        p.vertex = v.vertex;
        p.uv = v.uv;
        p.normal = v.normal;
        return p;
    }
    
    ENDHLSL
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM

            #pragma target 4.0

            #pragma fragment LitPassFragment

            sampler2D _MainTex, _SparkleNoise;
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float _Cutoff;
                float4 _BaseColor, _RimColor;
                float _RimPower;
                float4 _PathColorIn, _PathColorOut;
                float4 _TrailRimColor;
                float _PathBlending;
                float _TrailRimBlending;
                float _SparkleScale, _SparkCutoff;
                float _SnowTextureOpacity, _MainTextureScale;
                float4 _ShadowColor;
                float _ReceiveShadowMappingPosOffset;
            CBUFFER_END

            half4 LitPassFragment(MyVaryings IN) : SV_Target
            {
                
                // Calculate local uv.
                float3 positionWS = IN.positionWS;
                float2 uv = IN.positionWS.xz - _SandprintsCamPos.xz;
                uv /= (_SandprintsCamOrthoSize * 2);
                uv += 0.5;
                // Flip uv since indent depth is captured from underneath.
                uv.x = 1.0 - uv.x;
                float3 normal = normalize(IN.normal);
                
                // Read indent effect render texture.
                float4 indentValue = tex2D(_SandprintsIndentMap, uv);
                // Smoothstep mask to prevent bleeding.
                // indentValue *=  smoothstep(0.99, 0.9, uv.x) * smoothstep(0.99, 0.9,1- uv.x);
                // indentValue *=  smoothstep(0.99, 0.9, uv.y) * smoothstep(0.99, 0.9,1- uv.y);
                
                // worldspace Noise texture
                float3 topdownNoise = tex2D(_Noise, IN.positionWS.xz * _NoiseScale).rgb;
                
                // Worldspace Snow texture
                float3 mainTexture = tex2D(_MainTex, IN.positionWS.xz * _MainTextureScale).rgb;
                
                // Lerp between snow color and snow texture.
                float3 finalMainTexture = lerp(_BaseColor.rgb, mainTexture * _BaseColor.rgb, _SnowTextureOpacity);
                
                // Lerp the colors based on indent.
                float3 path = lerp(_PathColorOut.rgb * indentValue.r, _PathColorIn.rgb, saturate(indentValue.r * _PathBlending));
                float3 trailRim = lerp(_TrailRimColor.rgb * indentValue.g, _TrailRimColor.rgb, saturate(indentValue.g * _TrailRimBlending));
                float3 indentMainColors = lerp(finalMainTexture, path, saturate(indentValue.r));
                float3 indentRimMainColors = lerp(finalMainTexture, trailRim, saturate(indentValue.g - indentValue.r));
                float3 mainColors = lerp(indentMainColors, indentRimMainColors, saturate(indentValue.g * 2.0));
                
                // Lighting and shadows.
                Light mainLight = GetMainLight();
                float shadow = 0.0;
                float3 shadowTestPosWS = IN.positionWS.xyz + mainLight.direction * _ReceiveShadowMappingPosOffset;
                #if _MAIN_LIGHT_SHADOWS_CASCADE || _MAIN_LIGHT_SHADOWS
                    float4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS);
                    mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
                    shadow = mainLight.shadowAttenuation;
                #endif

                float4 litMainColors = float4(mainColors, 1);

                // Extra point lights.
                float3 extraLights;
                int pixelLightCount = GetAdditionalLightsCount();
                for (int j = 0; j < pixelLightCount; ++j)
                {
                    Light light = GetAdditionalLight(j, IN.positionWS, half4(1, 1, 1, 1));
                    float3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
                    extraLights += attenuatedLightColor;
                }
                extraLights *= litMainColors.rgb;

                // Sparkles.
                float sparklesStatic = tex2D(_SparkleNoise, IN.positionWS.xz * _SparkleScale).r;
                float cutoffSparkles = step(_SparkCutoff, sparklesStatic);
                litMainColors += cutoffSparkles * saturate(1 - (indentValue.r * 2)) * 4;
                
                // Rim light.
                half rim = 1.0 - dot((IN.viewDir), normal) * topdownNoise.r;
                litMainColors += _RimColor * pow(abs(rim), _RimPower);
                
                // Ambient and main light colors.
                half4 extraColors;
                extraColors.rgb = litMainColors.rgb * mainLight.color.rgb * (shadow + unity_AmbientSky.rgb);
                extraColors.a = 1;
                
                // Shadow colors.
                float3 coloredShadows = (shadow + (_ShadowColor.rgb * (1 - shadow)));
                litMainColors.rgb = litMainColors.rgb * mainLight.color * (coloredShadows);
                
                // Final color.
                float4 final = litMainColors + extraColors + float4(extraLights, 0);
                final.rgb = MixFog(final.rgb, IN.fogFactor);
                return final;
            }

            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull Off
            
            HLSLPROGRAM

            #pragma fragment ShadowCasterPassFragment;

            half4 ShadowCasterPassFragment(MyVaryings IN) : SV_TARGET
            {
                return 0.0;
            }

            ENDHLSL
        }
    }
}