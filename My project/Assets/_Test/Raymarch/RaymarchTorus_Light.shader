Shader "URP/RaymarchTorus_Light_Transparent"
{
    Properties
    {
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
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline" 
        }

        Pass
        {
            // --- ADICIONADO PARA TRANSPARÊNCIA ---
            Blend SrcAlpha OneMinusSrcAlpha // Mistura o Alpha do shader com o fundo
            ZWrite Off                      // Evita que o objeto transparente bloqueie outros no Depth Buffer
            Cull Off                        // Opcional: renderiza os dois lados da geometria (útil para raymarching)

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float3 _TorusCenter;
            float2 _TorusRadius;
            float4 _SphereColor;
            float3 _LightPosition;
            float4 _LightColor;
            float4x4 _WorldToLocalMatrix;
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
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS);
                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                return OUT;
            }
            
            float sdTorus( float3 p, float3 c, float2 t )
            {
                //float3 p_shifted = p - c;
                float3 p_shifted = mul(_WorldToLocalMatrix, float4(p,1));
                float2 q = float2(length(p_shifted.xz) - t.x, p_shifted.y);
                return length(q) - t.y;
            }

            float3 GetNormal(float3 p)
            {
                float2 e = float2(0.01, 0);
                float3 n = float3(
                    sdTorus(p + e.xyy, _TorusCenter, _TorusRadius) - sdTorus(p - e.xyy, _TorusCenter, _TorusRadius),
                    sdTorus(p + e.yxy, _TorusCenter, _TorusRadius) - sdTorus(p - e.yxy, _TorusCenter, _TorusRadius),
                    sdTorus(p + e.yyx, _TorusCenter, _TorusRadius) - sdTorus(p - e.yyx, _TorusCenter, _TorusRadius)
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
                    float d = sdTorus(p, _TorusCenter, _TorusRadius);
                    
                    if (d < 0.001) // Colisão
                    {
                        float3 normal = GetNormal(p);
                        float3 lightDir = normalize(_LightPosition - p);
                        float diff = saturate(dot(normal, lightDir));
                        
                        // Retorna a cor calculada com Alpha = 1 (opaco onde o torus existe)
                        return half4(_SphereColor.rgb * (diff * _LightColor.rgb), 1.0);
                    }

                    t += d;
                    if (t > 50.0) break;
                }

                // --- ALTERADO PARA FUNDO TRANSPARENTE ---
                // Retorna qualquer cor (ex: preto ou branco) com Alpha 0
                return half4(0, 0, 0, 0); 
            }
            ENDHLSL
        }
    }
}