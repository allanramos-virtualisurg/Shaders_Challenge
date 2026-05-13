Shader "URP/RaymarchRect_Light"
{
    Properties
    {
        // Propriedades expostas no Inspector, se quiser ajustar depois
        _TorusCenter ("Torus Center", Vector) = (0, 0, 5, 0)
        _SphereColor ("Sphere Color", Color) = (1, 1, 1, 1)
        _TorusRadius ("Torus Radius", Vector) = (1.0, 1.0, 0, 0)
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
            float3 _TorusCenter;
            float3 _TorusRadius;
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
            
            float sdBox( float3 p, float3 center, float3 b )
            {
                float3 p_shifted = p - center;
                
                float3 q = abs(p_shifted) - b;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            float3 GetNormal(float3 p)
            {
                float2 e = float2(0.01, 0); // O "passinho" para o lado

                // Calculamos a inclinação comparando o ponto atual com vizinhos
                float3 n = float3(
                sdBox(p + e.xyy, _TorusCenter, _TorusRadius) - sdBox(p - e.xyy, _TorusCenter, _TorusRadius),
                sdBox(p + e.yxy, _TorusCenter, _TorusRadius) - sdBox(p - e.yxy, _TorusCenter, _TorusRadius),
                sdBox(p + e.yyx, _TorusCenter, _TorusRadius) - sdBox(p - e.yyx, _TorusCenter, _TorusRadius)
                );
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
                    float d = sdBox(p,_TorusCenter, _TorusRadius);
                    
                    if (d < 0.001) // Colisão!
                    {
                        float3 normal = GetNormal(p);
                    
                        float3 lightDir = normalize(_LightPosition - p);
                    
                        float diff = saturate(dot(normal, lightDir));
                        
                        return half4(_SphereColor * (diff * _LightColor));
                        
                        
                        //return half4(1, 0, 0, 1);
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