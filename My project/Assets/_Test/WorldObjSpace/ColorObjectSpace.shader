Shader "Unlit/ObjectSpaceColorURP"
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
                float3 positionOS : TEXCOORD1;   // OS = Object Space
            };

            Varyings vert (Attributes input)
            {
                Varyings output;

                output.positionOS = input.positionOS;
                
                output.positionCS = TransformObjectToHClip(output.positionOS);
                
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                // half4 � mais perform�tico que float4 em dispositivos m�veis
                return half4(input.positionOS * 0.5 + 0.5, 1.0);
            }
            ENDHLSL
        }
    }
}