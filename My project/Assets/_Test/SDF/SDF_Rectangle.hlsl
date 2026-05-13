void RectangleSDF_float(float3 p, float4x4 WorldToLocalMatrix, float3 Size, out float Out)
{
    float3 r = mul(WorldToLocalMatrix, float4(p, 1));
    float3 d = abs(r) - Size;
    Out = length(max(d,0.0)) + min(max(d.x,max(d.y,d.z)),0.0);
}