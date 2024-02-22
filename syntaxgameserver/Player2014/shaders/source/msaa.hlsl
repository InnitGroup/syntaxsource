#include "common.h"

struct Appdata
{
    float4 p   : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertexOutput
{
    float4 p   : POSITION;
    float2 uv  : TEXCOORD0;
};


float4 convertPosition(float4 p, float scale)
{
	return p;
}

float2 convertUv(float4 p)
{
	return p.xy * 0.5 + 0.5;
}

VertexOutput msaaComposit_vs(Appdata IN)
{
    float2 uv = convertUv(IN.p);

    VertexOutput OUT;
    OUT.p = convertPosition(IN.p, 1);
    OUT.uv = uv;

    return OUT;
}

float4 msaaComposit_ps(float2 uv : TEXCOORD0, uniform sampler2D colorMap: register(s0)): COLOR0
{
    return tex2D(colorMap, uv);
}
