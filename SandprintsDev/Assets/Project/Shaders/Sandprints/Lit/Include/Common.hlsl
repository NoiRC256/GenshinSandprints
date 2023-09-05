#ifndef CommonCG
#define CommonCG

float3 mod2D289(float3 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float2 mod2D289(float2 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float3 permute(float3 x)
{
    return mod2D289(((x * 34.0) + 1.0) * x);
}

float snoise(float2 v)
{
    const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1;
    i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod2D289(i);
    float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    float3 x = 2.0 * frac(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float3 NormalFromHeight(float height, float3 worldNormal, float3 WorldPosition)
{
    float3 ase_worldNormal = worldNormal;
    float3 temp_output_16_0_g2 = (WorldPosition * 100.0);
    float3 crossY18_g2 = cross(ase_worldNormal, ddy(temp_output_16_0_g2));
    float3 worldDerivativeX2_g2 = ddx(temp_output_16_0_g2);
    float dotResult6_g2 = dot(crossY18_g2, worldDerivativeX2_g2);
    float crossYDotWorldDerivX34_g2 = abs(dotResult6_g2);
    float temp_output_20_0_g2 = height;
    float3 crossX19_g2 = cross(ase_worldNormal, worldDerivativeX2_g2);
    float3 break29_g2 = (sign(crossYDotWorldDerivX34_g2) * ((ddx(temp_output_20_0_g2) * crossY18_g2) + (ddy(temp_output_20_0_g2) * crossX19_g2)));
    float3 appendResult30_g2 = (float3(break29_g2.x, -break29_g2.y, break29_g2.z));
    float3 normalizeResult39_g2 = normalize(((crossYDotWorldDerivX34_g2 * ase_worldNormal) - appendResult30_g2));
    return normalizeResult39_g2;
}

float random(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123);
}

float remap(float value, float from1, float to1, float from2, float to2)
{
    return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
}

float randomMapped(float2 uv, float from, float to)
{
    return remap(random(uv), 0, 1, from, to);
}

float4 remapFlowTexture(float4 tex)
{
    return float4
    (
        remap(tex.x, 0, 1, -1, 1),
        remap(tex.y, 0, 1, -1, 1),
        0,
        remap(tex.w, 0, 1, -1, 1)
    );
}

float2 RectangularToPolar(float2 UV, float2 OffsetAngle)
{
    float2 uv = UV - OffsetAngle;
    float distance = length(uv);
    float angle01 = 0;
    float angle = 0;
    angle = atan2(uv.y, uv.x);
    angle01 = (angle / 3.14 * 0.5) + 0.5;
    return float2(angle01, distance);
}

float2 PolarToRectangular(float2 PolarUV)
{
    float angle = (PolarUV.x - 0.5) * 2 * 3.14159;
    float x = cos(angle) * PolarUV.y;
    float y = sin(angle) * PolarUV.y;
    float2 uv = float2(x, y) + float2(0.5, 0.5);
    return uv;
}

float2 PolarToRectangularWithOffset(float2 PolarUV, float2 PolarOffset)
{
    float angle = (PolarUV.x - 0.5) * 2 * 3.14159;
    float x = cos(angle) * PolarUV.y;
    float y = sin(angle) * PolarUV.y;
    float2 uv = float2(x, y) + PolarOffset;
    return uv;
}

half Gray(half3 color)
{
    half gray = color.r * 0.3 + color.g * 0.59 + color.b * 0.11;
    return gray;
}


#endif