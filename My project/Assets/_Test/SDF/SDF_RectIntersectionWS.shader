Shader "URP/SDF_Rect_Intersection_Solid"
{
    Properties
    {
        _BoxSize ("Box Size", Vector) = (0.1, 0.1, 0.5, 0)
        _Color ("Sphere Color", Color) = (1, 0, 0, 1)
        _BgColor ("Background Color", Color) = (0.2, 0.2, 0.2, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _BgColor;
                float4 _BoxSize;
                float4 _BoxCenter;
                float4x4 _WorldToLocalMatrix;
            CBUFFER_END

            struct Attributes 
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings 
            {
                float4 positionCS   : SV_POSITION; 
                float3 positionWS   : TEXCOORD0; 
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            float sdBox(float3 p, float3 boxSize)
            {
                float3 r = mul(_WorldToLocalMatrix, float4(p, 1));

                float3 q = abs(r) - boxSize;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            half4 frag (Varyings IN) : SV_Target
            {
                float box = sdBox(IN.positionWS, _BoxSize);

                float3 finalColor = box < 0 ? _Color.rgb : _BgColor.rgb;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}