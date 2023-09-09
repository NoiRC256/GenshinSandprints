Shader "NekoLabs/Sandprints/IndentMapPostProcess"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" { }
    }

    HLSLINCLUDE
    #pragma vertex vert
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    float4 _MainTex_TexelSize;
    float4 _MainTex_ST;

    struct Attributes
    {
        float4 positionOS : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    Varyings vert(Attributes IN)
    {
        Varyings OUT;
        OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
        OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
        return OUT;
    }
    ENDHLSL
    
    SubShader
    {
        Pass
        {
            Name "Downsample"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma target 3.0
            #pragma fragment frag_downsample

            float4 frag_downsample(Varyings i) : SV_TARGET
            {
                float4 offset = _MainTex_TexelSize.xyxy * float4(-0.5, -0.5, 0.5, 0.5);
                float r = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).r * 4;
                float g = r;
                r += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.xy).r;
                r += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.xw).r;
                r += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.zy).r;
                r += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.zw).r;

                float4 rimOffset = _MainTex_TexelSize.xyxy * float4(-1, -1, 1, 1) * 3;
                g += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + rimOffset.xy).r;
                g += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + rimOffset.xw).r;
                g += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + rimOffset.zy).r;
                g += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + rimOffset.zw).r;
                g = r > 0.0 ? 0.0 : g;
                g = g > 0.0 ? 1.0 : 0.0;

                return float4(r / 8, g / 8, 0, 0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Upsample"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma target 3.0
            #pragma fragment frag_upsample

            float4 frag_upsample(Varyings i) : SV_TARGET
            {
                float4 offset = _MainTex_TexelSize.xyxy * float4(-0.5, -0.5, 0.5, 0.5);
                float2 rg;
                rg = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + float2(offset.x, 0)).rg;
                rg += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + float2(offset.z, 0)).rg;
                rg += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + float2(0, offset.y)).rg;
                rg += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + float2(0, offset.w)).rg;
                rg += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.xy / 2.0).rg * 2;
                rg += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.xw / 2.0).rg * 2;
                rg += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.zy / 2.0).rg * 2;
                rg += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset.zw / 2.0).rg * 2;
                return float4(rg / 12, 0, 0);
            }
            ENDHLSL
        }
    }
}