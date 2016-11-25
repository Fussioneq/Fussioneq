cbuffer ConstantBuffer
{
    float4 color = float4(1.0f, 1.0f, 1.0f, 1.0f);
    float2 offset = float2(0.0f, 0.0f);
    float2 dimm = float2(1.0f, 1.0f);
}

struct VS_OUT
{
    float4 position : SV_POSITION;
};

VS_OUT VShader(float2 position : POSITION)
{
    VS_OUT output;
    float2 normPos = position + offset;
    normPos = (normPos / dimm) * float2(2.0f, -2.0f);
    normPos -= float2(1.0f, -1.0f);
    output.position = float4(normPos, 0.0f, 1.0f);
    return output;
}

float4 PShader(float4 position : SV_POSITION) : SV_TARGET
{
    return color;
}
