Shader "NekoLabs/SandprintMapPostProcess"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
      //   _offset ("Offset", float) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            // sampler2D _CameraOpaqueTexture;
            float4 _MainTex_TexelSize;
            float4 _MainTex_ST;
            
            float _BlurOffset;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f input) : SV_Target
            {
                float2 res = _MainTex_TexelSize.xy;
                float i = _BlurOffset;
    
                fixed4 col;                
                col.g = col.r = tex2D( _MainTex, input.uv ).r;
                col.g += tex2D( _MainTex, input.uv + float2( i, i ) * res ).r;
                col.g += tex2D( _MainTex, input.uv + float2( i, -i ) * res ).r;
                col.g += tex2D( _MainTex, input.uv + float2( -i, i ) * res ).r;
                col.g += tex2D( _MainTex, input.uv + float2( -i, -i ) * res ).r;
                col.g /= 5.0f;
                col.g = col.r > 0 ? 0 : col.g;
                col.g = col.g > 0 ? 1 : 0;
                
                return col;
            }
            ENDCG
        }
    }
}