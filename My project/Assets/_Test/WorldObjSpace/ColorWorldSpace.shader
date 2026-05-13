Shader "Unlit/WorldSpaceColorURP"
{
    Properties
    {
        // Propriedades aqui
    }
    SubShader
    {
        Tags { 
            "RenderType"="Opaque" 
            "RenderPipeline"="UniversalPipeline" // Importante para URP
        }

        Pass
        {
            HLSLPROGRAM // Mudamos de CG para HLSL
            #pragma vertex vert
            #pragma fragment frag

            // Inclui as bibliotecas essenciais do URP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION; // OS = Object Space
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION; // CS = Clip Space
                float3 positionWS : TEXCOORD1;   // WS = World Space
            };

            Varyings vert (Attributes input)
            {
                Varyings output;

                // Agora sim usamos o TransformObjectToWorld
                // Note que o URP prefere float3 para a posição mundial
                output.positionWS = TransformObjectToWorld(input.positionOS);
                
                // Converte para Clip Space (Substitui o UnityObjectToClipPos)
                output.positionCS = TransformWorldToHClip(output.positionWS);
                
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                // half4 é mais performático que float4 em dispositivos móveis
                return half4(input.positionWS, 1.0);
            }
            ENDHLSL
        }
    }
}