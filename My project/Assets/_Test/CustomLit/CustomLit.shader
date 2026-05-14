Shader "Custom/URP_PBR_Full"
{
    Properties
    {
        [Header(Base Maps)]
        _BaseMap("Albedo", 2D) = "white" {}
        _BaseColor("Color Tint", Color) = (1,1,1,1)
        
        [Header(Surfaces)]
        [Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Float) = 1.0
        
        _Metallic("Metallic", Range(0, 1)) = 0.0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5
        _MetallicGlossMap("Metallic (R) Smoothness (A)", 2D) = "white" {}
        
        [Header(Lighting)]
        _OcclusionMap("Occlusion", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1.0
        
        [HDR] _EmissionColor("Emission Color", Color) = (0,0,0)
        _EmissionMap("Emission Map", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Inclui as bibliotecas essenciais do URP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3  normalWS   : NORMAL_WS;
                half4  tangentWS  : TANGENT_WS; 
            };

            // CBUFFER para compatibilidade com SRP Batcher
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _Metallic;
                half _Smoothness;
                half _BumpScale;
                half _OcclusionStrength;
            CBUFFER_END

            TEXTURE2D(_BaseMap);           SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);         SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicGlossMap);  SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_OcclusionMap);      SAMPLER(sampler_OcclusionMap);
            TEXTURE2D(_EmissionMap);       SAMPLER(sampler_EmissionMap);

            Varyings vert(Attributes input) {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target {
                // 1. Amostragem das texturas
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _BumpScale);
                half4 specMap = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, input.uv);
                half occlusion = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, input.uv).r;
                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * _EmissionColor.rgb;

                // 2. Cálculos de Normal e Tangent Space
                half3 bitangent = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
                half3x3 TBN = half3x3(input.tangentWS.xyz, bitangent, input.normalWS);
                half3 worldNormal = normalize(mul(normalTS, TBN));

                // 3. Preparando SurfaceData (Dados do Material)
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo.rgb;
                // Combinamos o valor do slider com o mapa (R=Metallic, A=Smoothness)
                surfaceData.metallic = specMap.b * _Metallic;
                surfaceData.smoothness = specMap.g * _Smoothness;
                surfaceData.occlusion = LerpWhiteTo(occlusion, _OcclusionStrength);
                surfaceData.emission = emission;
                surfaceData.alpha = albedo.a;

                // 4. Preparando InputData (Dados da Geometria/Câmera)
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = worldNormal;
                inputData.viewDirectionWS = normalize(GetCameraPositionWS() - input.positionWS);
                //inputData.shadowCoord = GetShadowCoord(TransformWorldToShadowCoord(input.positionWS));
                inputData.bakedGI = SampleSH(worldNormal); // Iluminação indireta básica

                // 5. O "pulo do gato": Função PBR oficial do URP
                return UniversalFragmentPBR(inputData, surfaceData);
            }
            ENDHLSL
        }
    }
}