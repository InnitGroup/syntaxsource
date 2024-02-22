#include "globals.h"

sampler2D tex : register(s0);

//#define 

uniform float4 colorBias;
uniform float4 throttleFactor; // .x = alpha cutoff, .y = alpha boost (clamp)

struct VS_INPUT
{
	float4 pos : POSITION;
	float4 scaleRotLife : TEXCOORD0; // transform matrix
    float2 disp  : TEXCOORD1; // .xy = corner, either (0,0), (1,0), (0,1), or (1,1)
	float4 color0: COLOR0;
	float4 color1: COLOR1;
};

struct VS_OUTPUT
{
	float4 pos   : POSITION;
	float3 uvFog : TEXCOORD0;
	float4 color : COLOR0;
};

float4 rotScale( float4 scaleRotLife )
{
	float cr = cos( scaleRotLife.z );
	float sr = sin( scaleRotLife.z );

	float4 r;
	r.x = cr  * scaleRotLife.x;
	r.y = -sr * scaleRotLife.x;
	r.z =  sr * scaleRotLife.y;
	r.w =  cr * scaleRotLife.y;
	
	return r;
}


VS_OUTPUT vs( VS_INPUT input )
{
	VS_OUTPUT o;
	
	float4 pos  = float4( input.pos.xyz, 1 );
	float2 disp = input.disp.xy * 2 - 1; // -1..1

	input.scaleRotLife *= float4( 1/256.0f, 1/256.0f, 2 * 3.1415926f / 32767, 1 / 32767.0f );
	
	float4 rs = rotScale( input.scaleRotLife );

	pos += G.ViewRight * dot( disp, rs.xy );
	pos += G.ViewUp * dot( disp, rs.zw );
	o.pos = mul( G.ViewProjection, pos );
	
	o.uvFog.xy = input.disp.xy;
	o.uvFog.y = 1 - o.uvFog.y;
	o.uvFog.z = (G.FogParams.z - o.pos.w) * G.FogParams.w;
	float t = max( 0, min(1, input.scaleRotLife.w ) );
	o.color = lerp( input.color1, input.color0, t );

	// alpha channel magic for particle throttling
	float2 cmp   = o.color.aa < throttleFactor.xy;
	o.pos.xyz += cmp.xxx * (1e10f).xxx; // move the particle off-screen
	o.color.a = lerp( o.color.a, throttleFactor.y, cmp.y ); // if below threshold, alpha = threshold

	return o;
}

float4 psAdd( VS_OUTPUT input ) : COLOR0 // #0
{
	float4 color = tex2D( tex, input.uvFog.xy );
	float4 result = float4( input.color.rgb + color.rgb + colorBias.rgb, color.a * input.color.a );
	result.rgb = lerp( G.FogColor.rgb, result.rgb, saturate( input.uvFog.zzz ) );
	return result;
}

float4 psMul( VS_OUTPUT input ) : COLOR0 // #1
{
	float4 color = tex2D( tex, input.uvFog.xy );
	float4 result = input.color * color;
	result.rgb = lerp( G.FogColor.rgb, result.rgb, saturate( input.uvFog.zzz ) );
	return result;
}
