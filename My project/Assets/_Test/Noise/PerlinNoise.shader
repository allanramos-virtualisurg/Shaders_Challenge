Shader "URP/PerlinNoise"
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
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float _Scale;
                float _Speed;
                float4 _ColorA;
                float4 _ColorB;
            CBUFFER_END

            // Funções auxiliares para gerar o ruído gradiente
            float2 hash(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(p) * 43758.5453123);
            }

            float perlinNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                // Interpolação suave (Smoothstep)
                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(lerp(dot(hash(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
                                 dot(hash(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
                            lerp(dot(hash(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
                                 dot(hash(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x), u.y);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Adiciona tempo para animar o noise
                float2 animatedUV = IN.uv * _Scale + (_Time.y * _Speed);
                
                // O Perlin Noise retorna valores entre -1 e 1, 
                // mapeamos para 0 e 1 para exibição de cores
                float noise = perlinNoise(animatedUV);
                noise = noise * 0.5 + 0.5;

                // Interpola entre as duas cores escolhidas
                float4 finalColor = lerp(_ColorA, _ColorB, noise);
                
                //return finalColor;

                return half4(noise.xxxx);
            }
            ENDHLSL
        }
    }
}