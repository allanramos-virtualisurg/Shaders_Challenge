Shader "URP/CustomLit"
{
    Properties
    {
        _BaseMap("Albedo", 2D) = "white" {}
        _BaseColor("Color Tint", Color) = (1,1,1,1)
        
        [Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Float) = 1.0
        
        _ORMMap("Occlusion(R) Roughness (G) Metallic (B) ", 2D) = "white" {}
        _Metallic("Metallic", Range(0, 1)) = 0.0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5
        _OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1.0
        
        [HDR] _EmissionColor("Emission Color", Color) = (0,0,0)
        _EmissionMap("Emission Map", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        // --- PASS 1: FORWARD LIT (Receives Shadows) ---
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // REQUIRED: Shadows Multi-compile keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ DEBUG_DISPLAY

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
                float4 shadowCoord : TEXCOORD4;
            };

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
            TEXTURE2D(_ORMMap);            SAMPLER(sampler_ORMMap);
            TEXTURE2D(_EmissionMap);       SAMPLER(sampler_EmissionMap);

            Varyings vert(Attributes input) {
                Varyings output;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);
                
                // NEW: Calculate shadow coordinates correctly
                output.shadowCoord = GetShadowCoord(vertexInput);
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target 
            {
                // 1. Setup SurfaceData
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _BumpScale);
                half4 ormMap = SAMPLE_TEXTURE2D(_ORMMap, sampler_ORMMap, input.uv);
                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * _EmissionColor.rgb;

                half3 bitangent = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
                half3x3 TBN = half3x3(input.tangentWS.xyz, bitangent, input.normalWS);
                half3 worldNormal = normalize(mul(normalTS, TBN));

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo.rgb;
                surfaceData.metallic = ormMap.b * _Metallic;
                surfaceData.smoothness = ormMap.g * _Smoothness;
                surfaceData.occlusion = LerpWhiteTo(ormMap.r, _OcclusionStrength);
                surfaceData.emission = emission;
                surfaceData.alpha = albedo.a;

                // 2. Setup InputData
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = worldNormal;
                inputData.viewDirectionWS = normalize(GetCameraPositionWS() - input.positionWS);
                inputData.shadowCoord = input.shadowCoord;
                inputData.bakedGI = SampleSH(worldNormal);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                
                
                return UniversalFragmentPBR(inputData, surfaceData);
            }
            
            ENDHLSL
        }

        // --- PASS 2: SHADOW CASTER (Casts Shadows) ---
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            
            

            struct ShadowAttributes {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
            };

            struct ShadowVaryings {
                float4 positionCS   : SV_POSITION;
            };

            ShadowVaryings ShadowPassVertex(ShadowAttributes input) {
                ShadowVaryings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // Apply shadow bias to prevent artifacts
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz));
                return output;
            }

            half4 ShadowPassFragment(ShadowVaryings input) : SV_TARGET {
                return 0;
            }
            ENDHLSL
        }
    }
}