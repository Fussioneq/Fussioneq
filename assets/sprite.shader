
cbuffer ConstantBuffer : register(b0)
{
    float4 bounds = float4(0,0,0,0);
	float4 color = float4(1,1,1,1);
}

texture2D tex : register(s0);

SamplerState samp
{
 Filter = MIN_MAG_MIP_LINEAR;
 AddressU = Wrap;
 AddressV = Wrap;
};

struct VOut
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
};

VOut VShader(float4 position : POSITION, float2 uv : TEXCOORD0)
{
    VOut output;

	float2 xy = position.xy * float2( bounds.z, -bounds.w ) + float2(1.0, -1.0) * bounds.xy;
    output.position = float4(  float2( -1.0f, 1.0f ) + 2.0f * xy, 0.0f, 1.0f );
    output.uv = uv;
    return output;
}


float4 PShader(float4 position : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET
{
   return tex.Sample( samp, uv ) * color;
}
