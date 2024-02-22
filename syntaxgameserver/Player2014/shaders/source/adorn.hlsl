#include "globals.h"

struct Appdata
{
    float4 Position	    : POSITION;
    float2 Uv	        : TEXCOORD0;
    float3 Normal       : NORMAL0;
};

struct VertexOutput
{
    float4 HPosition    : POSITION;

    float2 Uv           : TEXCOORD0;
    float4 Color        : COLOR0;

    float FogFactor     : TEXCOORD1;
};

uniform float4x4 WorldMatrix;

uniform float4 Color;

VertexOutput AdornSelfLitVSGeneric(Appdata IN, float ambient)
{
    VertexOutput OUT = (VertexOutput)0;

    float4 position = mul(WorldMatrix, IN.Position);
    float3 normal = normalize(mul((float3x3)WorldMatrix, IN.Normal));

    float3 light = normalize(G.CameraPosition - position.xyz);
    float ndotl = saturate(dot(normal, light));

    float lighting = ambient + (1 - ambient) * ndotl;
    float specular = pow(ndotl, 64.0);

    OUT.HPosition = mul(G.ViewProjection, mul(WorldMatrix, IN.Position));
    OUT.Uv = IN.Uv;
    OUT.Color = float4(Color.rgb * lighting + specular, Color.a);

    OUT.FogFactor = (G.FogParams.z - OUT.HPosition.w) * G.FogParams.w;

    return OUT;
}

VertexOutput AdornSelfLitVS(Appdata IN)
{
    return AdornSelfLitVSGeneric(IN, 0.5f);
}

VertexOutput AdornSelfLitHighlightVS(Appdata IN)
{
    return AdornSelfLitVSGeneric(IN, 0.75f);
}

VertexOutput AdornVS(Appdata IN)
{
    VertexOutput OUT = (VertexOutput)0;

    float4 position = mul(WorldMatrix, IN.Position);

#ifdef PIN_LIGHTING
    float3 normal = normalize(mul((float3x3)WorldMatrix, IN.Normal));
    float ndotl = dot(normal, -G.Lamp0Dir);
    float3 lighting = G.AmbientColor + saturate(ndotl) * G.Lamp0Color + saturate(-ndotl) * G.Lamp1Color;
#else
    float3 lighting = 1;
#endif

    OUT.HPosition = mul(G.ViewProjection, position);
    OUT.Uv = IN.Uv;
    OUT.Color = float4(Color.rgb * lighting, Color.a);

    OUT.FogFactor = (G.FogParams.z - OUT.HPosition.w) * G.FogParams.w;

    return OUT;
}

sampler2D DiffuseMap: register(s0);

float4 AdornPS(VertexOutput IN): COLOR0
{
    float4 result = tex2D(DiffuseMap, IN.Uv) * IN.Color;

    result.rgb = lerp(G.FogColor, result.rgb, saturate(IN.FogFactor));

    return result;
}
