//#ifndef TESSELLATION_CGINC_INCLUDED
//#define TESSELLATION_CGINC_INCLUDED
#if defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_PSSL)
#define UNITY_CAN_COMPILE_TESSELLATION 1
#   define UNITY_domain                 domain
#   define UNITY_partitioning           partitioning
#   define UNITY_outputtopology         outputtopology
#   define UNITY_patchconstantfunc      patchconstantfunc
#   define UNITY_outputcontrolpoints    outputcontrolpoints
#endif

struct ControlPoint
{
    float4 vertex : INTERNALTESSPOS;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct MyVaryings
{
    float4 vertex : SV_Position;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 viewDir : TEXCOORD3;
    float fogFactor : TEXCOORD4;
};

struct MyAttributes
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

float _Tess;
float _MinTessDistance;
float _MaxTessDistance;

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

uniform float3 _SandprintsCamPos;
uniform float _SandprintsCamOrthoSize;
uniform sampler2D _SandprintsIndentMap;
uniform float4 _SandprintsIndentMap_TexelSize;
uniform float _SandprintsIndentValueToMeter;
uniform float _SandprintsCenterIndentValue;
sampler2D _Noise;
float _NoiseScale, _SnowHeight, _NoiseWeight, _SnowDepth, _TrailRimHeight;
float _NormalSmoothThreshold;

// Hull program.

TessellationFactors GetTriEdgeTessFactors(float3 triVertexFactors)
{
    TessellationFactors tess;
    tess.edge[0] = 0.5 * (triVertexFactors.y + triVertexFactors.z);
    tess.edge[1] = 0.5 * (triVertexFactors.x + triVertexFactors.z);
    tess.edge[2] = 0.5 * (triVertexFactors.x + triVertexFactors.y);
    tess.inside = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
    return tess;
}

float GetDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
{
    float3 positionWS = mul(unity_ObjectToWorld, vertex).xyz;
    float dist = distance(positionWS, _WorldSpaceCameraPos);
    float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0);
    return f * tess;
}

TessellationFactors DistanceBasedTess(float4 v0, float4 v1, float4 v2, float minDist, float maxDist, float tess)
{
    float3 f;
    f.x = GetDistanceTessFactor(v0, minDist, maxDist, tess);
    f.y = GetDistanceTessFactor(v1, minDist, maxDist, tess);
    f.z = GetDistanceTessFactor(v2, minDist, maxDist, tess);
    return GetTriEdgeTessFactors(f);
}

TessellationFactors FixedTess(float tess)
{
    float3 f = (tess, tess, tess);
    return GetTriEdgeTessFactors(f);
}

TessellationFactors PatchConstants(InputPatch < ControlPoint, 3 > patch)
{
    float minDist = _MinTessDistance;
    float maxDist = _MaxTessDistance;
    TessellationFactors f;
    // Tessellate only within distance.
    f = DistanceBasedTess(patch[0].vertex, patch[1].vertex, patch[2].vertex, minDist, maxDist, _Tess);
    //f = FixedTess(_Tess);
    return f;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_odd")]
[UNITY_patchconstantfunc("PatchConstants")]
ControlPoint TessellationHull(InputPatch < ControlPoint, 3 > patch, uint id : SV_OutputControlPointID)
{
    return patch[id];
}

// Domain program.

MyVaryings PostTessellationVertex(MyAttributes input);

[UNITY_domain("tri")]
MyVaryings TessellationDomain(TessellationFactors factors, OutputPatch < ControlPoint, 3 > patch, float3 barycentricCoordinates : SV_DomainLocation)
{
    MyAttributes v;
    
    #define Interpolate(fieldName) v.fieldName = \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;
    
    Interpolate(vertex)
    Interpolate(uv)
    Interpolate(normal)
    
    return PostTessellationVertex(v);
}

// Vertex program after tessellation.

float4 GetShadowPositionHClip(MyAttributes input, float3 normal)
{
    float3 positionWS = TransformObjectToWorld(input.vertex.xyz);
    float3 normalWS = TransformObjectToWorldNormal(normal);
    
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, 0));
    
    #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
        positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
    return positionCS;
}

MyVaryings PostTessellationVertex(MyAttributes input)
{
    MyVaryings output;
    
    // Calculate local uv.
    float3 positionWS = TransformObjectToWorld(input.vertex.xyz);
    float2 uv = (positionWS.xz - _SandprintsCamPos.xz) / (_SandprintsCamOrthoSize * 2);
    uv += 0.5;
    // Flip uv since indent depth is captured from underneath.
    uv.x = 1.0 - uv.x;
    
    // Read indent effect render texture.
    float2 indentMap = tex2Dlod(_SandprintsIndentMap, float4(uv, 0, 0)).rg;
    float indentPixelValue = indentMap.r;
    float indentRimValue = indentMap.g;

    // Smoothstep mask to prevent bleeding.
    // indentValue *=  smoothstep(0.99, 0.9, uv.x) * smoothstep(0.99, 0.9,1- uv.x);
    // indentValue *=  smoothstep(0.99, 0.9, uv.y) * smoothstep(0.99, 0.9,1- uv.y);
    
    // Worldspace noise texture.
    float SnowNoise = tex2Dlod(_Noise, float4(positionWS.xz * _NoiseScale, 0, 0)).r;
    
    // Vertex displacement coefficients.
    float3 normalCoef = SafeNormalize(input.normal);
    float3 extraHeightCoef = saturate((_SnowHeight) + (SnowNoise * _NoiseWeight));

    // Extra height displacement.
    input.vertex.xyz += normalCoef * extraHeightCoef;
    float3 worldPos = TransformObjectToWorld(input.vertex.xyz);
    float groundHeight = worldPos.y;
    float groundHeightPixelValue = 1.0 - (clamp(groundHeight - _SandprintsCamPos.y, 0.0, 10.0) / _SandprintsIndentValueToMeter);
    float normalizedIndentDepth = clamp(indentPixelValue - groundHeightPixelValue, 0.0, 1.0) * _SandprintsIndentValueToMeter;
    float indentRim = indentRimValue * _TrailRimHeight;
    // Indent displacement.
    worldPos.y -= saturate(normalizedIndentDepth);
    worldPos.y += saturate(indentRim);
    input.vertex.xyz = TransformWorldToObject(worldPos);

    // Outputs.
    #ifdef SHADERPASS_SHADOWCASTER
        output.vertex = GetShadowPositionHClip(input, normal);
    #else
        output.vertex = TransformObjectToHClip(input.vertex.xyz);
    #endif
    output.normal = input.normal;
    output.uv = input.uv;
    output.positionWS = TransformObjectToWorld(input.vertex.xyz);
    output.viewDir = SafeNormalize(GetCameraPositionWS() - output.positionWS);
    output.fogFactor = ComputeFogFactor(output.vertex.z);
    return output;
}
