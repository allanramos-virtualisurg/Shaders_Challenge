Shader "URP/RaymarchSphere_SimpleColor"
{
    Properties
    {
        // Propriedades expostas no Inspector, se quiser ajustar depois
        _SphereCenter ("Sphere Center", Vector) = (0, 0, 5, 0)
        _SphereRadius ("Sphere Radius", Float) = 1.0
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Inclui as bibliotecas essenciais do URP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            // Variáveis globais (definidas nas Properties ou via C#)
            float3 _SphereCenter;
            float _SphereRadius;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                // Transforma posição local para mundo
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS);
                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                
                return OUT;
            }

            // SDF da Esfera
            float sdSphere(float3 p, float3 center, float radius)
            {
                return length(p - center) - radius;
            }
            
            half4 frag(Varyings IN) : SV_Target
            {
                // 1. Origem: Posição da câmera no mundo (URP utiliza _WorldSpaceCameraPos)
                float3 rayOrigin = _WorldSpaceCameraPos;

                // 2. Direção: Do olho para o ponto no Quad
                float3 rayDirection = normalize(IN.positionWS - rayOrigin);

                // 3. Loop de Raymarching
                float t = 0;
                for (int i = 0; i < 64; i++)
                {
                    float3 p = rayOrigin + rayDirection * t;
                    float d = sdSphere(p, _SphereCenter, _SphereRadius);

                    if (d < 0.001) // Colisão!
                    {
                        return half4(1, 0, 0, 1); // Vermelho
                    }

                    t += d;

                    if (t > 50.0) break; // Limite de distância
                }

                // Se o raio não bater em nada
                return half4(1, 1, 1, 1); // Branco
            }
            ENDHLSL
        }
    }
}