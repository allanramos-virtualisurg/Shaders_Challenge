void CircleSDF_float(float3 Position, float3 Center, float Radius, out float Out)
{
    Out = length(Position - Center) - Radius;
}