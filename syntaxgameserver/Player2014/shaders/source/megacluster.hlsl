#include "common.h"

struct Appdata
{
    float4 Position	    : POSITION;
    float3 Normal	    : NORMAL;
    float4 Uv		    : TEXCOORD0;
#ifdef PIN_HQ
    float4 EdgeDistances: TEXCOORD1;
    float3 Tangent      : TEXCOORD2;
#endif
};

struct VertexOutput
{
    float4 HPosition    : POSITION;

    float4 UvHigh_EdgeDistance1 : TEXCOORD0;
    float4 UvLow_EdgeDistance2  : TEXCOORD1;

    float4 LightPosition_Fog : TEXCOORD2;

#ifdef PIN_HQ
    float4 View_Depth        : TEXCOORD3;
    float4 Normal_Blend      : TEXCOORD4;
    float3 Tangent           : TEXCOORD5;
#else
    float4 Diffuse_Blend     : COLOR0;
#endif

    float3 PosLightSpace     : TEXCOORD7;
};

uniform float4x4 WorldMatrix;

VertexOutput MegaClusterVS(Appdata IN)
{
    VertexOutput OUT = (VertexOutput)0;
    
    // Decode vertex data
    IN.Normal = (IN.Normal - 127) / 127;
    IN.Uv /= 2048;

    // Transform position and normal to world space
    // Note: world matrix does not contain rotation/scale for static geometry so we can avoid transforming normal
	float3 posWorld = mul(WorldMatrix, IN.Position).xyz;
    float3 normalWorld = IN.Normal;

	OUT.HPosition = mul(G.ViewProjection, float4(posWorld, 1));

    float blend = OUT.HPosition.w / 200;

    OUT.LightPosition_Fog = float4(lgridPrepareSample(lgridOffset(posWorld, normalWorld)), (G.FogParams.z - OUT.HPosition.w) * G.FogParams.w);

    OUT.UvHigh_EdgeDistance1.xy = IN.Uv.xy;
    OUT.UvLow_EdgeDistance2.xy = IN.Uv.zw;

#ifdef PIN_HQ
    OUT.View_Depth = float4(posWorld, OUT.HPosition.w * G.FadeDistance.y);
    float4 edgeDistances = IN.EdgeDistances*G.FadeDistance.z + 0.5 * OUT.View_Depth.w;

    OUT.UvHigh_EdgeDistance1.zw = edgeDistances.xy;
    OUT.UvLow_EdgeDistance2.zw = edgeDistances.zw;

    OUT.View_Depth.xyz = G.CameraPosition - posWorld;
    OUT.Normal_Blend = float4(IN.Normal, blend);
    // decode tangent
    OUT.Tangent = (IN.Tangent - 127) / 127;
#else
    // IF LQ shading is performed in VS
    float ndotl = dot(normalWorld, -G.Lamp0Dir);
    float3 diffuse = saturate(ndotl) * G.Lamp0Color + max(-ndotl, 0) * G.Lamp1Color;

    OUT.Diffuse_Blend = float4(diffuse, blend);
#endif

    OUT.PosLightSpace = getPosInLightSpace(posWorld);

	return OUT;
}

sampler2D DiffuseHighMap: register(s0);
sampler2D DiffuseLowMap: register(s1);
sampler2D NormalMap: register(s2);
sampler2D SpecularMap: register(s3);
LGRID_SAMPLER LightMap: register(s4);
sampler2D LightMapLookup: register(s5);

void MegaClusterPS(VertexOutput IN,
#ifdef PIN_GBUFFER
    out float4 oColor1: COLOR1,
#endif
    out float4 oColor0: COLOR0)
{
    float4 high = tex2D(DiffuseHighMap, IN.UvHigh_EdgeDistance1.xy);
    float4 low = tex2D(DiffuseLowMap, IN.UvLow_EdgeDistance2.xy);

    float4 light = lgridSample(LightMap, LightMapLookup, IN.LightPosition_Fog.xyz);
    float shadow = getBlobShadow(IN.PosLightSpace) * light.a;

#ifdef PIN_HQ
    float3 albedo = lerp(high.rgb, low.rgb, saturate1(IN.Normal_Blend.a));

    // sample normal map and specular map
    float4 normalMapSample = tex2D(NormalMap, IN.UvHigh_EdgeDistance1.xy);
    float4 specularMapSample = tex2D(SpecularMap, IN.UvHigh_EdgeDistance1.xy);

    // compute bitangent and world space normal
    float3 bitangent = cross(IN.Normal_Blend.xyz, IN.Tangent.xyz);
    float3 nmap = nmapUnpack(normalMapSample);
    float3 normal = normalize(nmap.x * IN.Tangent.xyz + nmap.y * bitangent + nmap.z * IN.Normal_Blend.xyz);

    float ndotl = dot(normal, -G.Lamp0Dir);
    float3 diffuseIntensity = saturate0(ndotl) * G.Lamp0Color + max(-ndotl, 0) * G.Lamp1Color;
    float specularIntensity = step(0, ndotl) * specularMapSample.r;
    float specularPower = specularMapSample.g * 255 + 0.01;

    // Compute diffuse and specular and combine them
    float3 diffuse =  (G.AmbientColor + diffuseIntensity * shadow + light.rgb) * albedo.rgb;
    float3 specular = G.Lamp0Color * (specularIntensity * shadow * (float)(half)pow(saturate(dot(normal, normalize(-G.Lamp0Dir + normalize(IN.View_Depth.xyz)))), specularPower));
    oColor0.rgb = diffuse + specular;

    // apply outlines
    float outlineFade = saturate1(IN.View_Depth.w * G.OutlineBrightness_ShadowInfo.x + G.OutlineBrightness_ShadowInfo.y);
    float2 minIntermediate = min(IN.UvHigh_EdgeDistance1.wz, IN.UvLow_EdgeDistance2.wz);
    float minEdgesPlus = min(minIntermediate.x, minIntermediate.y) / IN.View_Depth.w;
    oColor0.rgb *= saturate1(outlineFade * (1.5 - minEdgesPlus) + minEdgesPlus);

    oColor0.a = 1;

#else
     float3 albedo = lerp(high.rgb, low.rgb, saturate1(IN.Diffuse_Blend.a));

    // Compute diffuse term
    float3 diffuse = (G.AmbientColor + IN.Diffuse_Blend.rgb * shadow + light.rgb) * albedo.rgb;

    // Combine
    oColor0.rgb = diffuse;
    oColor0.a = 1;

#endif

    float fogAlpha = saturate(IN.LightPosition_Fog.w);

    oColor0.rgb = lerp(G.FogColor, oColor0.rgb, fogAlpha);

#ifdef PIN_GBUFFER
    oColor1 = gbufferPack(IN.View_Depth.w*G.FadeDistance.x, diffuse.rgb, 0, fogAlpha);
#endif
}
