Shader "URP/RaymarchSphere_Light"
{
    Properties
    {
        // Propriedades expostas no Inspector, se quiser ajustar depois
        _SphereCenter ("Sphere Center", Vector) = (0, 0, 5, 0)
        _SphereColor ("Sphere Color", Color) = (1, 1, 1, 1)
        _SphereRadius ("Sphere Radius", Float) = 1.0
        _LightPosition ("Light Position", Vector) = (0.5, 0.5, -1, 0)
        _LightColor ("Light Color", Color) = (1, 1, 1, 1)
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
            float4 _SphereColor;
            float3 _LightPosition;
            float4 _LightColor;
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
            float GetSceneDist(float3 p)
            {
                return length(p - _SphereCenter) - _SphereRadius;
            }

            float3 GetNormal(float3 p)
            {
                //float2 e = float2(0.01, 0); // O "passinho" para o lado

                // Calculamos a inclinação comparando o ponto atual com vizinhos
                //float3 n = float3(
                //GetSceneDist(p + e.xyy) - GetSceneDist(p - e.xyy),
                //GetSceneDist(p + e.yxy) - GetSceneDist(p - e.yxy),
                //GetSceneDist(p + e.yyx) - GetSceneDist(p - e.yyx)
                //);
                
                // Normal calculada a partir do centro da esfera
                float3 n = p - _SphereCenter;

                return normalize(n);
            }
            

            half4 frag(Varyings IN) : SV_Target
            {
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(IN.positionWS - rayOrigin);

                float t = 0;
                for (int i = 0; i < 64; i++)
                {
                    float3 p = rayOrigin + rayDirection * t;
                    float d = GetSceneDist(p); // Usar a função unificada

                    if (d < 0.001) // Colisão!
                    {
                        // Calcula a normal APENAS aqui, depois do hit
                        float3 normal = GetNormal(p);
                        
                        float3 lightDir = normalize(_LightPosition - p);
                        
                        // O produto escalar (dot) diz o quanto a luz está de frente para a superfície
                        float diff = saturate(dot(normal, lightDir));
                        
                        // para ficar colorido e bonito
                        return half4(_SphereColor * (diff * _LightColor));
                    }

                    t += d;
                    if (t > 50.0) break;
                }

                return half4(1, 1, 1, 1); // Branco (fundo)
            }
            ENDHLSL
        }
    }
}