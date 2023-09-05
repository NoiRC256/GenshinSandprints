Shader "NekoLabs/Sandprints/Lit" {
    Properties{
        [Header(Main)]
        _Noise("Ground Noise", 2D) = "gray" {}
        _NoiseScale("Ground Noise Scale", Range(0,2)) = 0.1
        _NoiseWeight("Ground Noise Weight", Range(0,2)) = 0.1
        [HDR]_ShadowColor("Ground Shadow Color", Color) = (0.5,0.5,0.5,1)
        
        [Space]
        [Header(Tesselation)]
        _MinTessDistance("Min Tessellation Distance", Float) = 10
        _MaxTessDistance("Max Tessellation Distance", Float) = 20
        _Tess("Tessellation", Range(1,64)) = 20
        
        [Space]
        [Header(Ground)]
        [HDR]_Color("Base Color", Color) = (0.5,0.5,0.5,1)
        [HDR]_PathColorIn("Indent Color In", Color) = (0.5,0.5,0.7,1)
        [HDR]_PathColorOut("Indent Color Out", Color) = (0.5,0.5,0.7,1)
        [HDR]_TrailRimColor("Indent Rim Color", Color) = (1,1,1,1)
        _PathBlending("Indent Blending", Range(0,10)) = 0.3
        _TrailRimBlending("Indent Rim Blending", Range(0,10)) = 0.3
        _MainTex("Main Texture", 2D) = "white" {}
        _SnowHeight("Ground Height", Range(0,1)) = 0.3
        _SnowDepth("Trail Depth", Range(0,1)) = 1
        _TrailRimHeight("Trail Rim Height", Range(0,1)) = 0.3
        _SnowTextureOpacity("Main Texture Opacity", Range(0,2)) = 0.3
        _SnowTextureScale("Main Texture Scale", Range(0,2)) = 0.3
        
        [Space]
        [Header(Sparkles)]
        _SparkleScale("Sparkle Scale", Range(0,10)) = 10
        _SparkCutoff("Sparkle Cutoff", Range(0,10)) = 0.8
        _SparkleNoise("Sparkle Noise", 2D) = "gray" {}
        
        [Space]
        [Header(Rim)]
        _RimPower("Rim Power", Range(0,20)) = 20
        [HDR]_RimColor("Rim Color Snow", Color) = (0.5,0.5,0.5,1)

        [Header(Shadow mapping)]
        _NormalSmoothThreshold("Normal Smooth Threshold", Float) = 0.01
        _ReceiveShadowMappingPosOffset("Receive Shadow Offset", Float) = 0
    }
    HLSLINCLUDE
    
    // Includes
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #include "SandprintsTessellation.hlsl"

    #pragma require tessellation tessHW
    #pragma vertex TessellationVertexProgram
    #pragma hull hull
    #pragma domain domain

    // Keywords
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
    #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile_fog

    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
    #pragma multi_compile_fragment _ _SHADOWS_SOFT
    
    ControlPoint TessellationVertexProgram(Attributes v)
    {
        ControlPoint p;
        p.vertex = v.vertex;
        p.uv = v.uv;
        p.normal = v.normal;
        return p;
    }
    ENDHLSL
    
    SubShader{
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        Pass{
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            // vertex happens in snowtessellation.hlsl
            #pragma fragment frag
            #pragma target 4.0
            
            sampler2D _MainTex, _SparkleNoise;
            CBUFFER_START(UnityPerMaterial)
                float4 _Color, _RimColor;
                float _RimPower;
                float4 _PathColorIn, _PathColorOut;
                float4 _TrailRimColor;
                float _PathBlending;
                float _TrailRimBlending;
                float _SparkleScale, _SparkCutoff;
                float _SnowTextureOpacity, _SnowTextureScale;
                float4 _ShadowColor;
                // shadow mapping
                float _ReceiveShadowMappingPosOffset;
            CBUFFER_END

            half4 frag(Varyings IN) : SV_Target{
                
                // Calculate local uv.
                float3 vertexWorldPosition = mul(unity_ObjectToWorld, IN.vertex).xyz;
                float2 uv = IN.worldPos.xz - _SandprintsCamPos.xz;
                uv /= (_SandprintsCamOrthoSize * 2);
                uv += 0.5;
                // Flip uv since indent depth is captured from underneath.
                uv.x = 1.0 - uv.x;
                
                // Read indent effect render texture.
                float4 indentRT = tex2D(_SandprintsRT, uv);
                // Smoothstep mask to prevent bleeding.
                indentRT *=  smoothstep(0.99, 0.9, uv.x) * smoothstep(0.99, 0.9,1- uv.x);
                indentRT *=  smoothstep(0.99, 0.9, uv.y) * smoothstep(0.99, 0.9,1- uv.y);
                //indentRT.r = indentRT.r > 0.5 ? 1.0 : 0.0;
                
                // worldspace Noise texture
                float3 topdownNoise = tex2D(_Noise, IN.worldPos.xz * _NoiseScale).rgb;
                
                // worldspace Snow texture
                float3 snowtexture = tex2D(_MainTex, IN.worldPos.xz * _SnowTextureScale).rgb;
                
                //lerp between snow color and snow texture
                float3 snowTex = lerp(_Color.rgb,snowtexture * _Color.rgb, _SnowTextureOpacity);
                
                //lerp the colors using the indentRT
                float3 path = lerp(_PathColorOut.rgb * indentRT.r, _PathColorIn.rgb, saturate(indentRT.r * _PathBlending));
                float3 trailRim = lerp(_TrailRimColor.rgb, _TrailRimColor.rgb, saturate(indentRT.g * _TrailRimBlending));
                float3 indentMainColors = lerp(snowTex, path, saturate(indentRT.r));
                float3 indentRimMainColors = lerp(snowTex, trailRim, saturate(indentRT.g - indentRT.r));
                float3 mainColors = lerp(indentMainColors, indentRimMainColors, saturate(indentRT.g * 2.0));
                
                // lighting and shadow information
                // float shadow = 0;
                // Light mainLight = GetMainLight();
                // float3 shadowTestPosWS = IN.worldPos + mainLight.direction * _ReceiveShadowMappingPosOffset;
                // half4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS);
                // mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
                // shadow = mainLight.shadowAttenuation; 

                Light mainLight = GetMainLight();
                float shadow = 1;
                float3 shadowTestPosWS = IN.worldPos.xyz + mainLight.direction * _ReceiveShadowMappingPosOffset;
                #if _MAIN_LIGHT_SHADOWS_CASCADE || _MAIN_LIGHT_SHADOWS
                    float4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS);
                    mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
                    shadow = mainLight.shadowAttenuation;
                #endif
                // #if _MAIN_LIGHT_SHADOWS_CASCADE || _MAIN_LIGHT_SHADOWS
                //     Light mainLight = GetMainLight(shadowCoord);
                //     shadow = mainLight.shadowAttenuation;
                // #else
                //     Light mainLight = GetMainLight();
                // #endif
                
                // extra point lights support
                float3 extraLights;
                int pixelLightCount = GetAdditionalLightsCount();
                for (int j = 0; j < pixelLightCount; ++j) {
                    Light light = GetAdditionalLight(j, IN.worldPos, half4(1, 1, 1, 1));
                    float3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
                    extraLights += attenuatedLightColor;			
                }
                
                float4 litMainColors = float4(mainColors,1) ;
                extraLights *= litMainColors.rgb;
                // add in the sparkles
                float sparklesStatic = tex2D(_SparkleNoise, IN.worldPos.xz * _SparkleScale).r;
                float cutoffSparkles = step(_SparkCutoff,sparklesStatic);				
                litMainColors += cutoffSparkles  *saturate(1- (indentRT.r * 2)) * 4;
                
                // add rim light
                half rim = 1.0 - dot((IN.viewDir), IN.normal) * topdownNoise.r;
                litMainColors += _RimColor * pow(abs(rim), _RimPower);
                
                // ambient and mainlight colors added
                half4 extraColors;
                extraColors.rgb = litMainColors.rgb * mainLight.color.rgb * (shadow + unity_AmbientSky.rgb);
                extraColors.a = 1;
                
                // colored shadows
                float3 coloredShadows = (shadow + (_ShadowColor.rgb * (1-shadow)));
                litMainColors.rgb = litMainColors.rgb * mainLight.color * (coloredShadows);
                
                // everything together
                float4 final = litMainColors + extraColors + float4(extraLights,0);
                // add in fog
                final.rgb = MixFog(final.rgb, IN.fogFactor);
                return final;

                half4 color = 0;
                color.rgb = IN.normal;
                return color;
                
            }
            ENDHLSL
            
        }
        
        // casting shadows is a little glitchy, I've turned it off, but maybe in future urp versions it works better?
        // Shadow Casting Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull Off
            
            HLSLPROGRAM
            #pragma target 3.0
            
            // Support all the various light  ypes and shadow paths
            #pragma multi_compile_shadowcaster
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            
            // Register our functions
            
            #pragma fragment frag
            // A custom keyword to modify logic during the shadow caster pass
            
            half4 frag(Varyings IN) : SV_Target{
                return 0;
            }
            
            ENDHLSL
        }
    }
}