Shader "URP/SDF_Rect_Intersection_OS"
{
    Properties
    {
        _Color ("Sphere Color", Color) = (1, 0, 0, 1)
        _BgColor ("Background Color", Color) = (0.2, 0.2, 0.2, 1)
        _BoxSize ("Box Size", Vector) = (0.1, 0.1, 0.5, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            // Inclui as bibliotecas essenciais do URP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _BgColor;
                float4 _BoxSize;
            CBUFFER_END

            struct Attributes 
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings 
            {
                float4 positionCS   : SV_POSITION; 
                float3 positionOS   : TEXCOORD0;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                
                // Salvamos a posição local (Object Space) para usar no fragmento
                OUT.positionOS = IN.positionOS;
                
                // Transformação obrigatória para Clip Space
                // Usamos GetVertexPositionInputs para garantir compatibilidade total
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS);
                OUT.positionCS = vertexInput.positionCS;
                
                return OUT;
            }

            // Sua função de caixa (SDF Box)
            float sdBox(float3 p, float3 boxSize)
            {
                float3 q = abs(p) - boxSize;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // Cálculo da caixa usando a posição local
                // Aqui você define o tamanho da caixa: 0.1 x 0.1 x 0.5
                float box = sdBox(IN.positionOS, _BoxSize);

                // Se box < 0, estamos dentro da forma.
                float3 finalColor = (box < 0) ? _Color.rgb : _BgColor.rgb;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}