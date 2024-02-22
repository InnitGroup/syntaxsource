struct Globals
{
    float4x4 ViewProjection;

    float4 ViewRight;
    float4 ViewUp;
    float3 CameraPosition;

    float3 AmbientColor;
    float3 Lamp0Color;
    float3 Lamp0Dir;
    float3 Lamp0Right;
    float3 Lamp0Up;
    float3 Lamp1Color;

    float3 FogColor;
    float4 FogParams;

    float4 LightBorder;
    float4 LightConfig0;
    float4 LightConfig1;
    float4 LightConfig2;
    float4 LightConfig3;

    float3 FadeDistance;
    float4 OutlineBrightness_ShadowInfo;

    float4 BlobShadowData0;
    float4 BlobShadowData1;
    float4 BlobShadowData2;
    float4 BlobShadowData3;
};

uniform Globals G: register(c0);
