Shader "Custom/Voronoi3D"
{
    Properties
    {
        _CellSize ("Cell Size", Float) = 5.0
        _Speed ("Animation Speed", Float) = 1.0
        _Edge1 ("Edge 1", Float) = 0.0
        _Edge2 ("Edge 2", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

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
                //float3 worldPos : TEXCOORD0;
                float3 objPos : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float _CellSize;
                float _Speed;
                float _Edge1;
                float _Edge2;
            CBUFFER_END

            // Hash 3D para gerar pontos aleatórios dentro de cubos
            float3 hash33(float3 p)
            {
                p = float3(dot(p, float3(127.1, 311.7, 74.7)),
                           dot(p, float3(269.5, 183.3, 246.1)),
                           dot(p, float3(113.5, 271.9, 124.6)));
                return frac(sin(p) * 43758.5453);
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
                float3 p = IN.objPos * _CellSize;
                float3 g = floor(p);
                float3 f = frac(p);

                float minDist = 1.0;

                // Loop 3x3x3 (27 iterações) para encontrar o ponto mais próximo no espaço 3D
                for (int z = -1; z <= 1; z++)
                {
                    for (int y = -1; y <= 1; y++)
                    {
                        for (int x = -1; x <= 1; x++)
                        {
                            float3 neighbor = float3(float(x), float(y), float(z));
                            float3 pointInCell = hash33(g + neighbor);
                            
                            // Animação 3D dos pontos internos
                            pointInCell = 0.5 + 0.5 * sin(_Time.y * _Speed + 6.2831 * pointInCell);
                            
                            float3 diff = neighbor + pointInCell - f;
                            float dist = length(diff);

                            minDist = min(minDist, dist);
                        }
                    }
                }

                // Aplica o smoothstep para contraste
                float v = smoothstep(_Edge1, _Edge2, minDist);
                
                return half4(v.xxx, 1.0);
            }
            ENDHLSL
        }
    }
}