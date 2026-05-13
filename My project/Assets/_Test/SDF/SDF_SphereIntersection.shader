Shader "URP/SDF_Sphere_Intersection"
{
    Properties
    {
        _SphereCenter ("Sphere Center", Vector) = (0, 0, 0, 0)
        _SphereRadius ("Sphere Radius", Float) = 1.0
        _Color ("Sphere Color", Color) = (1, 0, 0, 1)
        _Smoothness ("_Smoothness", Range(0.001, 0.1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // CBUFFER para compatibilidade com o SRP Batcher
            CBUFFER_START(UnityPerMaterial)
                float4 _SphereCenter;
                float _SphereRadius;
                float4 _Color;
                float _Smoothness;
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
                // Transforma para World Space
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                // Transforma para Clip Space (HClip)
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            // Função SDF da Esfera
            float sdSphere(float3 p, float3 center, float s)
            {
                return distance(p, center) - s;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // Calcula a distância no espaço de mundo
                float d = sdSphere(IN.positionWS, _SphereCenter.xyz, _SphereRadius);

                // No URP, usamos smoothstep para garantir que o círculo 
                // não fique com "escadinhas" (aliasing)
                float mask = 1.0 - smoothstep(-_Smoothness, _Smoothness, d);

                // Descarta pixels fora da esfera para otimizar (opcional)
                if (mask < 0.001) discard;

                return half4(_Color.rgb, mask * _Color.a);
            }
            ENDHLSL
        }
    }
}