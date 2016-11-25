cbuffer ConstantBuffer : register(b0)
{
	float4 gaze = float4(0,0,0,0);
	float4 gaze1 = float4(0,0,0,0);
	float4 gaze2 = float4(0,0,0,0);
	float4 gaze3 = float4(0,0,0,0);
	float4 gaze4 = float4(0,0,0,0);
	float4 gaze5 = float4(0,0,0,0);
	float4 gaze6 = float4(0,0,0,0);
	float4 gaze7 = float4(0,0,0,0);
	float4 aspect = float4(0,0,0,0);
	float4 decay = float4(0,0,0,0);
	float4 strength = float4(0,0,0,0);
	float4 radius = float4(0,0,0,0);
	float4 color = float4(1,1,1,1);
	float4 gradient = float4(0,0,0,0);
}

Texture2D tex[2] : register(s0);

SamplerState samp
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};


struct VS_OUT
{
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

float circle(float2 pos, float2 uv, float rad)
{
	float d = length(pos * float2(aspect.x, 1.0) - uv * float2(aspect.x, 1.0));
	float t = clamp(d / rad, 0.0, 1.0);
	return 1.0 - t;
}


VS_OUT VS_Main(float4 position : POSITION, float2 uv : TEXCOORD0)
{
	VS_OUT output;
	output.pos = float4(float2(-1.0f, 1.0f) + float2(2.0, -2.0f) * position.xy, 1.0f, 1.0f);
	output.uv = uv;
	return output;
}


float4 PS_Main(float4 position : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET
{
	float h = tex[0].Sample(samp, uv).x;
	float4 col = lerp( color * float4(1,1,1,saturate(h) ), color * tex[1].Sample(samp, float2( saturate(h*0.13f), 0)), gradient.x );
	#ifdef _DEBUG
		float4 outcol = col * col.a;
	#else
		float4 outcol = col;
	#endif
	return outcol;
}

VS_OUT VS_Accumulate(float4 position : POSITION, float2 uv : TEXCOORD0)
{
	VS_OUT output;
	output.pos = float4(float2(-1.0f, 1.0f) + float2(2.0, -2.0f) * position.xy, 1.0f, 1.0f);
	output.uv = uv;
	return output;
}

float4 PS_Accumulate(float4 position : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET
{
	float c = circle(gaze.xy, uv, radius.x);
	c += circle(gaze1.xy, uv, radius.x);
	c += circle(gaze2.xy, uv, radius.x);
	c += circle(gaze3.xy, uv, radius.x);
	c += circle(gaze4.xy, uv, radius.x);
	c += circle(gaze5.xy, uv, radius.x);
	c += circle(gaze6.xy, uv, radius.x);
	c += circle(gaze7.xy, uv, radius.x);
	float prev = tex[0].Sample(samp, uv).x;
	float next = prev * decay.x + c * strength.x;
	return float4(next, 0.0, 0.0, 1.0);
}
