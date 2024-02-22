#include "common.h"

// tweakables
#define SSAO_NUM_PAIRS         8
#define SSAO_SPHERE_RAD        2.0f   // world-space
#define SSAO_MIN_PIXEL_RANGE   10.0f
#define SSAO_MAX_PIXEL_RANGE   100.0f
#define BLUR_DEPTH_DELTA       0.4f

#define COMPOSITE_DEPTH_DELTA    0.02f              
#define COMPOSITE_DEPTH_DELTA2   0.4f

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


// .xy = gbuffer width/height, .zw = inverse gbuffer width/height
uniform float4 TextureSize;

#ifdef GLSL
float4 convertPosition(float4 p, float scale)
{
	return p;
}

float2 convertUv(float4 p)
{
	return p.xy * 0.5 + 0.5;
}
#else
float4 convertPosition(float4 p, float scale)
{
	// half-pixel offset
	return p + float4(-TextureSize.z, TextureSize.w, 0, 0) * scale;
}

float2 convertUv(float4 p)
{
	return p.xy * float2(0.5, -0.5) + 0.5;
}
#endif

VertexOutput ssao_vs(Appdata IN)
{
    float2 uv = convertUv(IN.p);

    VertexOutput OUT;
    OUT.p = convertPosition(IN.p, 1);
    OUT.uv = uv;

    return OUT;
}

// used for depth downsampling pass
struct VertexOutput_4uv
{
    float4 p    : POSITION;
    float2 uv   : TEXCOORD0;
	float4 uv12 : TEXCOORD1;
	float4 uv34 : TEXCOORD2;
};

VertexOutput_4uv ssaoDepthDown_vs(Appdata IN)
{
    float2 uv = convertUv(IN.p);

    VertexOutput_4uv OUT;
    OUT.p = convertPosition(IN.p, 2);
    OUT.uv = uv;

	float2 uvOffset = TextureSize.zw * 0.5f;

	OUT.uv12.xy = uv + uvOffset * float2(-1, -1);
	OUT.uv12.zw = uv + uvOffset * float2(+1, -1);
	OUT.uv34.xy = uv + uvOffset * float2(-1, +1);
	OUT.uv34.zw = uv + uvOffset * float2(+1, +1);

    return OUT;
}

struct VertexOutput_8uv
{
    float4 p    : POSITION;
    float2 uv   : TEXCOORD0;
	float4 uv12 : TEXCOORD1;
	float4 uv34 : TEXCOORD2;
	float4 uv56 : TEXCOORD3;
	float4 uv78 : TEXCOORD4;
};

// used for ssao blurring passes
VertexOutput_8uv ssaoBlur_vs(Appdata IN, float2 uvOffset)
{
    float2 uv = convertUv(IN.p);

    VertexOutput_8uv OUT;
    OUT.p = convertPosition(IN.p, 2);
	OUT.uv = uv;

	OUT.uv12.xy = uv + 1 * uvOffset;
	OUT.uv12.zw = uv + 2 * uvOffset;
	OUT.uv34.xy = uv + 3 * uvOffset;
	OUT.uv34.zw = uv + 4 * uvOffset;
	
	OUT.uv56.xy = uv - 1 * uvOffset;
	OUT.uv56.zw = uv - 2 * uvOffset;
	OUT.uv78.xy = uv - 3 * uvOffset;
	OUT.uv78.zw = uv - 4 * uvOffset;
	
    return OUT;
}

VertexOutput_8uv ssaoBlurX_vs(Appdata IN)
{
	return ssaoBlur_vs(IN, float2(TextureSize.z * 2, 0));
}

VertexOutput_8uv ssaoBlurY_vs(Appdata IN)
{
	return ssaoBlur_vs(IN, float2(0, TextureSize.w * 2));
}

float unpackDepth( sampler2D s, float2 uv )
{
	float4 geomTex = tex2D(s, uv);
	float d = geomTex.z * (1.0f/256.0f) + geomTex.w;
	return d;
}

float getDepth( sampler2D s, float2 uv )
{
	return (float)tex2D(s,uv).r;
}

#define NUM_PAIRS   SSAO_NUM_PAIRS
#define RANGE 60.0/1024.0

#define pi 3.14159265359
#define RAD(X) ( (X) * (pi/180) )

float2 GetRotatedSample(float i)
{
	return (i+1) / (NUM_PAIRS+2) * float2(cos( RAD(45) + i / NUM_PAIRS * 2 * pi ), sin( RAD(45) + i / NUM_PAIRS * 2 * pi ) );
}

#define NUM_SAMPLES NUM_PAIRS*2+1

float4 ssao_ps(
    float2 uv: TEXCOORD0,
    uniform sampler2D depthBuffer: register(s0),
    uniform sampler2D randMap: register(s1)): COLOR0
{
	float2 mapSize = TextureSize.xy / 2;

	float baseDepth = getDepth( depthBuffer, uv );
	
	float4 noiseTex = tex2D(randMap, uv*mapSize/4) * 2 - 1;
	
	float2x2 rotation = 
	{
		{ noiseTex.y, noiseTex.x },
		{ -noiseTex.x, noiseTex.y }
	};
	
	float2 OFFSETS1[NUM_PAIRS] =
	{
		GetRotatedSample(0),
		GetRotatedSample(1),
		GetRotatedSample(2),
		GetRotatedSample(3),
		GetRotatedSample(4),
		GetRotatedSample(5),
#if NUM_PAIRS > 6
		GetRotatedSample(6),
		GetRotatedSample(7),
#if NUM_PAIRS > 8
		GetRotatedSample(8),
		GetRotatedSample(9),
		GetRotatedSample(10),
		GetRotatedSample(11),
#endif
#endif
	};
	
	float occ = 1;
	
	float sphereRadiusZB = (float) ( 2.0f / GBUFFER_MAX_DEPTH );
	
#define MINPIXEL SSAO_MIN_PIXEL_RANGE
#define MAXPIXEL SSAO_MAX_PIXEL_RANGE
	
	float radiusTex = (float)clamp( 0.5*sphereRadiusZB / baseDepth, MINPIXEL / mapSize.x, MAXPIXEL / mapSize.y);
	
	float numSamples = 2;
	
	for(int i = 0; i < NUM_PAIRS; i++)
	{
		float2 offset1 = mul(rotation, OFFSETS1[i]);
	
		float2 offseted1 = uv + offset1 * radiusTex;
		float2 offseted2 = uv - offset1 * radiusTex;
		
		float2 offsetDepth;
		offsetDepth.x = getDepth( depthBuffer, offseted1 );
		offsetDepth.y = getDepth( depthBuffer, offseted2 );
		
		float2 diff = offsetDepth - baseDepth.xx;
		
		float normalizedOffsetLen = (float)(i+1)/(NUM_PAIRS+2);
		
		float segmentDiff = (float) ( 1.5f*sphereRadiusZB*sqrt(1-normalizedOffsetLen*normalizedOffsetLen) );
		
		float2 normalizedDiff = (diff / segmentDiff) + 0.5;
		
		float minDiff = min(normalizedDiff.x, normalizedDiff.y);
		
		// At 0, full sample
		// At -1, zero sample, zero weight
		
		float sampleadd = (float) saturate(1+minDiff);
		
		float a = (float)(saturate(normalizedDiff.x) + saturate(normalizedDiff.y))*sampleadd;
		occ += a;
		numSamples += 2 * sampleadd;
 	}
	
	occ = occ / numSamples;

	float finalocc = (float)saturate(occ*2);
	
	if(baseDepth - (1.0f-1/256.0f) > 0)
		finalocc += 1;
	
	return float4(finalocc, finalocc, finalocc, 1);
}

// this function estimates depth discrepancy tolerance for the blur filter
float depthTolerance( float baseDepth, float sphereRadiusZB )
{
	float ramp = 80; // tweak
	return (  clamp(  sphereRadiusZB * (baseDepth * ramp) , 0.1f * sphereRadiusZB, 40*sphereRadiusZB  ) );
}

float ssaoBlur(
	float2 uv,
	
	float4 uv12,
	float4 uv34,
	float4 uv56, 
	float4 uv78,

	sampler2D map, 
	sampler2D depthBuffer
	)
{
	float sphereRadiusZB = BLUR_DEPTH_DELTA / GBUFFER_MAX_DEPTH;
	float4 i = { 1, 2, 3, 4 };
	float4 iw = 4-i;
    float4 denom = 1;


    float4 sum = tex2D(map, uv).rrrr * denom;
	
	float baseDepth = getDepth( depthBuffer, uv );
	
	float4 newDepth, delta, ssample, coef;

	newDepth.x = getDepth( depthBuffer, uv12.xy );
	newDepth.y = getDepth( depthBuffer, uv12.zw );
	newDepth.z = getDepth( depthBuffer, uv34.xy );
	newDepth.w = getDepth( depthBuffer, uv34.zw );
	
	delta = (newDepth - baseDepth.xxxx);
	coef  = iw * ( abs(delta) < depthTolerance( baseDepth, sphereRadiusZB ).xxxx  );
	
	
	ssample.x = tex2D( map, uv12.xy ).r;
	ssample.y = tex2D( map, uv12.zw ).r;
	ssample.z = tex2D( map, uv34.xy ).r;
	ssample.w = tex2D( map, uv34.zw ).r;
	
	sum += ssample * coef;
	denom += coef;

	////////////////////////////////////////
	
	newDepth.x = getDepth( depthBuffer, uv56.xy );
	newDepth.y = getDepth( depthBuffer, uv56.zw );
	newDepth.z = getDepth( depthBuffer, uv78.xy );
	newDepth.w = getDepth( depthBuffer, uv78.zw );
	
	delta = newDepth - baseDepth.xxxx;
	coef  = iw * ( abs(delta) <  depthTolerance( baseDepth, sphereRadiusZB ).xxxx );
	
	ssample.x = tex2D( map, uv56.xy ).r;
	ssample.y = tex2D( map, uv56.zw ).r;
	ssample.z = tex2D( map, uv78.xy ).r;
	ssample.w = tex2D( map, uv78.zw ).r;
	
	sum += ssample * coef;
	denom += coef;
	
	return dot( sum, float4(1,1,1,1) ) / dot( denom, float4(1,1,1,1) );
}


float4 ssaoBlurX_ps(
	float2 uv : TEXCOORD0,
	float4 uv12 : TEXCOORD1,
	float4 uv34 : TEXCOORD2,
	float4 uv56 : TEXCOORD3,
	float4 uv78 : TEXCOORD4,
	
    uniform sampler2D map : register(s0), uniform sampler2D depthBuffer : register(s1) ): COLOR0
{
	//return tex2D( map, uv );
    float ssaoTerm = ssaoBlur( uv, uv12, uv34, uv56, uv78, map, depthBuffer);

    return float4(ssaoTerm.xxx, 1);
}

#define SPECULAR_WEIGHT 3


float4 ssaoBlurY_ps(
	float2 uv : TEXCOORD0,
	float4 uv12 : TEXCOORD1,
	float4 uv34 : TEXCOORD2,
	float4 uv56 : TEXCOORD3,
	float4 uv78 : TEXCOORD4,
	
    uniform sampler2D map : register(s0), uniform sampler2D depthBuffer : register(s1), uniform sampler2D geomMap : register(s2) ): COLOR0
{
    float ssaoTerm = ssaoBlur(uv, uv12, uv34, uv56, uv78,  map, depthBuffer);

    float4 geom = tex2D(geomMap, uv);
    
    float specular = geom.x;
    float diffuse = geom.y;
	
    // Making specular kill SSAO faster, so it doesn't get capped by 1
    return (SPECULAR_WEIGHT*specular + diffuse * ssaoTerm) / (SPECULAR_WEIGHT*specular + diffuse + 0.001);
}



float4 ssaoDepthDown_ps( 
	float2 uv : TEXCOORD0, 
	float4 uv12 : TEXCOORD1,
	float4 uv34 : TEXCOORD2,
	
	uniform sampler2D depthBuffer : register(s0)  
) : COLOR0
{

	float4 d;
	d.x = unpackDepth( depthBuffer, uv12.xy );
	d.y = unpackDepth( depthBuffer, uv12.zw );
	d.z = unpackDepth( depthBuffer, uv34.xy );
	d.w = unpackDepth( depthBuffer, uv34.zw );
	
	float2 tmp = min( d.xy, d.zw );
	return min( tmp.x, tmp.y ).x;
}

VertexOutput_4uv ssaoComposit_vs(Appdata IN)
{
    float2 uv = convertUv(IN.p);

    VertexOutput_4uv OUT;
    OUT.p = convertPosition(IN.p, 1);
    OUT.uv = uv;

	float2 uvOffset = TextureSize.zw * 2;

	OUT.uv12.xy = uv + float2(uvOffset.x, 0);
	OUT.uv12.zw = uv - float2(uvOffset.x, 0);
	OUT.uv34.xy = uv + float2(0, uvOffset.y);
	OUT.uv34.zw = uv - float2(0, uvOffset.y);

    return OUT;
}

float4 ssaoCompositBlank_ps(float2 uv : TEXCOORD0, uniform sampler2D colorMap: register(s0)): COLOR0
{
    return tex2D(colorMap, uv);
}
 
#define CMP_LESS(X,Y) (  (X) < (Y) )

float4 ssaoComposit_ps(
	float2 uv : TEXCOORD0,
	float4 uv12 : TEXCOORD1,
	float4 uv34 : TEXCOORD2,
	
	uniform sampler2D colorMap :    register(s0),
	uniform sampler2D map :         register(s1), 
	uniform sampler2D gbuffer :     register(s2),
	uniform sampler2D depthBuffer:  register(s3)
	): COLOR0
{
	//return float4(1,0,0,1);
	float depth_range  = COMPOSITE_DEPTH_DELTA / GBUFFER_MAX_DEPTH;
	float depth_range2 = COMPOSITE_DEPTH_DELTA2 / GBUFFER_MAX_DEPTH;

	// we're here
	float baseDepth = unpackDepth( gbuffer, uv );
	float ssaoTerm = 1.0f; 

	float depth = getDepth( depthBuffer, uv );
	float diff = abs( depth - baseDepth );
	ssaoTerm = tex2D( map, uv ).x;
	
	float chk1 = CMP_LESS( depth_range, diff );   // can we trust the base depth? 0 - yes, 1 - no
	float4 ssaoTermNew = 0, chk2, depth2, diff2; 

	depth2.x  = getDepth( depthBuffer, uv12.xy );
	depth2.y  = getDepth( depthBuffer, uv12.zw );
	depth2.z  = getDepth( depthBuffer, uv34.xy );
	depth2.w  = getDepth( depthBuffer, uv34.zw );

	ssaoTermNew.x = tex2D( map, uv12.xy ).x;
	ssaoTermNew.y = tex2D( map, uv12.zw ).x;
	ssaoTermNew.z = tex2D( map, uv34.xy ).x;
	ssaoTermNew.w = tex2D( map, uv34.zw ).x;

	diff2 = abs( depth2 - baseDepth.xxxx );
	chk2  = CMP_LESS( diff2, depth_range2.xxxx );
	
	ssaoTermNew *= chk2;
	float den = dot( chk2, 1 ); // + 1e-5f;    - TODO: add this if we encounter glitches; // 
	ssaoTermNew.x = dot( ssaoTermNew, 1 ) / den;

	// the final decision: pick the base sample or its estimate, if base depth in unauthorative
	ssaoTerm = saturate(den*chk1) ? ssaoTermNew.x :  ssaoTerm;

	return tex2D(colorMap, uv) * ssaoTerm;
}
