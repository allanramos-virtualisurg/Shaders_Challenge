Shader "Custom/VoronoiURP"
{
    Properties
    {
        _CellSize ("Cell Size", Float) = 5.0
        _Speed ("Animation Speed", Float) = 1
        _Edge1 ("Edge1", Float) = 0
        _Edge2 ("Edge2", Float) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

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

            float _CellSize;
            float _Speed;
            float _Edge1;
            float _Edge2;

            // Função de Hash para aleatoriedade determinística
            float2 hash22(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
                return frac(sin(p) * 43758.5453);
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
                float2 uv = IN.uv * _CellSize;
                float2 g = floor(uv);
                float2 f = frac(uv);

                float minDist = 1.0;

                // Loop 3x3 para verificar células vizinhas
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(float(x), float(y));
                        // Ponto aleatório na célula vizinha
                        float2 pointInCell = hash22(g + neighbor);
                        
                        // Animação dos pontos
                        pointInCell = 0.5 + 0.5 * sin(_Time.y * _Speed + 6.2831 * pointInCell);
                        
                        // Vetor entre o pixel e o ponto
                        float2 diff = neighbor + pointInCell - f;
                        float dist = length(diff);

                        minDist = min(minDist, dist);
                    }
                }

                // Interpolação de cores baseada na distância
                //return lerp(_ColorA, _ColorB, minDist);
                
                float v = smoothstep(_Edge1, _Edge2, minDist.xxxx);
                
                return half4(v.xxxx);
            }
            ENDHLSL
        }
    }
}