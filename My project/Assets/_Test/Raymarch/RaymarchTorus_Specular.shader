Shader "URP/RaymarchTorus_Specular"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _TorusRadius ("Torus Radius", Vector) = (1.0, 1.0, 0, 0)
        
        // Novas propriedades para o Specular
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Glossiness ("Glossiness (Shininess)", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha 
            ZWrite Off                      
            Cull Off                        

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float2 _TorusRadius;
            float4 _Color;
            float4 _SpecularColor;
            float _Glossiness;
            float4x4 _WorldToLocalMatrix;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 positionWS : TEXCOORD0; };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS);
                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                return OUT;
            }
            
            float sdTorus(float3 p, float2 t)
            {
                float3 p_shifted = mul(_WorldToLocalMatrix, float4(p, 1)).xyz;
                float2 q = float2(length(p_shifted.xz) - t.x, p_shifted.y);
                return length(q) - t.y;
            }

            float3 GetNormal(float3 p)
            {
                float2 e = float2(0.001, 0);
                return normalize(float3(
                    sdTorus(p + e.xyy, _TorusRadius) - sdTorus(p - e.xyy, _TorusRadius),
                    sdTorus(p + e.yxy, _TorusRadius) - sdTorus(p - e.yxy, _TorusRadius),
                    sdTorus(p + e.yyx, _TorusRadius) - sdTorus(p - e.yyx, _TorusRadius)
                ));
            }
            
            half4 frag(Varyings IN) : SV_Target
            {
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 viewDir = normalize(IN.positionWS - rayOrigin); // Direção do raio

                Light mainLight = GetMainLight();

                float t = 0;
                for (int i = 0; i < 64; i++)
                {
                    float3 p = rayOrigin + viewDir * t;
                    float d = sdTorus(p, _TorusRadius);
                    
                    if (d < 0.001) 
                    {
                        float3 normal = GetNormal(p);
                        float3 lightDir = mainLight.direction;
                        
                        // --- DIFFUSE ---
                        float diff = saturate(dot(normal, lightDir));
                        
                        // --- SPECULAR (Blinn-Phong) ---
                        float3 halfVec = normalize(lightDir + (-viewDir)); // Vetor médio entre luz e visão
                        float specDot = saturate(dot(normal, halfVec));
                        
                        float specularExp = exp2(_Glossiness * 11) + 2;
                        float specular = pow(specDot, specularExp);
                        
                        // --- AMBIENT ---
                        float3 ambient = SampleSH(normal) * 0.2; 
                        
                        // COMBINAÇÃO FINAL
                        float3 diffuseRes = _Color.rgb * diff * mainLight.color;
                        float3 specularRes = _SpecularColor.rgb * specular * mainLight.color;
                        
                        float3 finalColor = diffuseRes + specularRes + ambient;
                        
                        return half4(finalColor, _Color.a);
                    }

                    t += d;
                    if (t > 50.0) break;
                }

                return half4(0, 0, 0, 0); 
            }
            ENDHLSL
        }
    }
}