Shader "URP/SDF_Sphere_Intersection_Solid"
{
    Properties
    {
        _SphereCenter ("Sphere Center", Vector) = (0, 0, 0, 0)
        _SphereRadius ("Sphere Radius", Float) = 1.0
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
                float4 _SphereCenter;
                float _SphereRadius;
                float4 _Color;
                float4 _BgColor;
            CBUFFER_END

            struct Attributes // Entrada: o que vem do modelo 3D
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings // Saída do vértice -> Entrada do fragmento
            {
                float4 positionCS   : SV_POSITION; // clip space
                float3 positionWS   : TEXCOORD0; // world space
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            float sdSphere(float3 p, float3 center, float s)
            {
                return distance(p, center) - s;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                float circle = sdSphere(IN.positionWS, _SphereCenter.xyz, _SphereRadius);

                float3 finalColor = circle < 0 ? _Color.rgb:_BgColor.rgb;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}