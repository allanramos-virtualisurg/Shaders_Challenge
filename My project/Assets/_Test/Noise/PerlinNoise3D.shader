Shader "URP/PerlinNoise3D"
{
    Properties
    {
        _Scale ("Noise Scale", Float) = 10.0
        _Speed ("Animation Speed", Float) = 1.0
        _ColorA ("Color A", Color) = (0, 0, 0, 1)
        _ColorB ("Color B", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 objPos : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float _Scale;
                float _Speed;
                float4 _ColorA;
                float4 _ColorB;
            CBUFFER_END

            // Hash 3D para gerar gradientes aleatórios nos vértices do cubo
            float3 hash(float3 p)
            {
                p = float3(dot(p, float3(127.1, 311.7, 74.7)),
                           dot(p, float3(269.5, 183.3, 246.1)),
                           dot(p, float3(113.5, 271.9, 124.6)));
                return -1.0 + 2.0 * frac(sin(p) * 43758.5453123);
            }

            float perlinNoise3D(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);

                // Quinta ordem (Quintic) suaviza melhor que o Smoothstep comum
                // f * f * f * (f * (f * 6.0 - 15.0) + 10.0)
                float3 u = f * f * (3.0 - 2.0 * f);

                // Cálculo dos 8 vértices do cubo
                float d000 = dot(hash(i + float3(0, 0, 0)), f - float3(0, 0, 0));
                float d100 = dot(hash(i + float3(1, 0, 0)), f - float3(1, 0, 0));
                float d010 = dot(hash(i + float3(0, 1, 0)), f - float3(0, 1, 0));
                float d110 = dot(hash(i + float3(1, 1, 0)), f - float3(1, 1, 0));
                float d001 = dot(hash(i + float3(0, 0, 1)), f - float3(0, 0, 1));
                float d101 = dot(hash(i + float3(1, 0, 1)), f - float3(1, 0, 1));
                float d011 = dot(hash(i + float3(0, 1, 1)), f - float3(0, 1, 1));
                float d111 = dot(hash(i + float3(1, 1, 1)), f - float3(1, 1, 1));

                // Interpolação Trilinear
                return lerp(
                    lerp(lerp(d000, d100, u.x), lerp(d010, d110, u.x), u.y),
                    lerp(lerp(d001, d101, u.x), lerp(d011, d111, u.x), u.y), 
                    u.z
                );
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.objPos = IN.positionOS.xyz;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Criamos um float3 de entrada (Posição + Tempo para animar o volume)
                float3 p = IN.objPos * _Scale;
                p.z += _Time.y * _Speed; // Move o noise através do eixo Z
                
                float noise = perlinNoise3D(p);
                noise = noise * 0.5 + 0.5; // Normaliza para 0-1

                float4 finalColor = lerp(_ColorA, _ColorB, noise);
                return finalColor;
            }
            ENDHLSL
        }
    }
}