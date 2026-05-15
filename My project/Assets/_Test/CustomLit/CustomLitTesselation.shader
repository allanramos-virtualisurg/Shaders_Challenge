Shader "URP/CustomLitTessellation"
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
        
        [Header(Tessellation Settings)]
        [Space(10)]
        _Tess ("Tessellation Factor", Range(1, 64)) = 4
        _MaxTessDist ("Max Tessellation Distance", Float) = 20
        _HeightMap ("Height Map (Displacement)", 2D) = "gray" {}
        _Displacement ("Displacement Amount", Range(0, 1)) = 0.1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex TessellationVertex
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // --- Estruturas ---
            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct ControlPoint {
                float4 positionOS : INTERNAL_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float2 uv : TEXCOORD0;
                half3 normalWS : NORMAL_WS;
                half4 tangentWS : TANGENT_WS;
            };

            struct TessFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // --- Variáveis e Texturas ---
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _Metallic;
                half _Smoothness;
                half _BumpScale;
                half _OcclusionStrength;
                float _Tess;
                float _Displacement;
                float _MaxTessDist;
            CBUFFER_END

            TEXTURE2D(_BaseMap);           SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);         SAMPLER(sampler_NormalMap);
            TEXTURE2D(_ORMMap);            SAMPLER(sampler_ORMMap);
            TEXTURE2D(_EmissionMap);       SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_HeightMap);         SAMPLER(sampler_HeightMap);

            // --- Vertex Stage ---
            ControlPoint TessellationVertex(Attributes v) {
                ControlPoint o;
                o.positionOS = v.positionOS;
                o.uv = v.uv;
                o.normalOS = v.normalOS;
                o.tangentOS = v.tangentOS;
                return o;
            }

            // --- Tessellation Logic ---
            float CalcDistanceTessFactor(float3 worldPos) {
                float dist = distance(worldPos, _WorldSpaceCameraPos);
                float factor = clamp(1.0 - (dist / _MaxTessDist), 0.01, 1.0);
                return factor * _Tess;
            }

            TessFactors patchConstantFunc(InputPatch<ControlPoint, 3> patch) {
                TessFactors f;
                float3 p0 = TransformObjectToWorld(patch[0].positionOS.xyz);
                float3 p1 = TransformObjectToWorld(patch[1].positionOS.xyz);
                float3 p2 = TransformObjectToWorld(patch[2].positionOS.xyz);

                float t0 = CalcDistanceTessFactor(p0);
                float t1 = CalcDistanceTessFactor(p1);
                float t2 = CalcDistanceTessFactor(p2);

                f.edge[0] = 0.5 * (t1 + t2);
                f.edge[1] = 0.5 * (t0 + t2);
                f.edge[2] = 0.5 * (t0 + t1);
                f.inside = (t0 + t1 + t2) / 3.0;
                return f;
            }

            [domain("tri")]
            [partitioning("fractional_odd")]
            [outputtopology("triangle_cw")]
            [patchconstantfunc("patchConstantFunc")]
            [outputcontrolpoints(3)]
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID) {
                return patch[id];
            }

            // --- Domain Shader (Onde a mágica acontece) ---
            [domain("tri")]
            Varyings domain(TessFactors factors, OutputPatch<ControlPoint, 3> patch, float3 bary : SV_DomainLocation) {
                Varyings o;

                // Interpolação de dados
                float3 posOS = patch[0].positionOS.xyz * bary.x + patch[1].positionOS.xyz * bary.y + patch[2].positionOS.xyz * bary.z;
                o.uv = patch[0].uv * bary.x + patch[1].uv * bary.y + patch[2].uv * bary.z;
                float3 normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
                float4 tangentOS = patch[0].tangentOS * bary.x + patch[1].tangentOS * bary.y + patch[2].tangentOS * bary.z;

                // Deslocamento (Displacement)
                float height = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv, 0).r;
                posOS += normalOS * height * _Displacement;

                o.positionWS = TransformObjectToWorld(posOS);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.normalWS = TransformObjectToWorldNormal(normalOS);
                o.tangentWS = float4(TransformObjectToWorldDir(tangentOS.xyz), tangentOS.w);

                return o;
            }

            // --- Fragment Shader (PBR) ---
            half4 frag(Varyings i) : SV_Target {
                // 1. Amostragens
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv) * _BaseColor;
                half3 normalSample = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _BumpScale);
                half4 ormMap = SAMPLE_TEXTURE2D(_ORMMap, sampler_ORMMap, i.uv);
                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, i.uv).rgb * _EmissionColor.rgb;

                // 2. Normal Mapping (TBN)
                half3 bitangent = cross(i.normalWS, i.tangentWS.xyz) * i.tangentWS.w;
                half3x3 TBN = half3x3(i.tangentWS.xyz, bitangent, i.normalWS);
                half3 normalWS = normalize(mul(normalSample, TBN));

                // 3. Surface Data
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo.rgb;
                surfaceData.occlusion = LerpWhiteTo(ormMap.r, _OcclusionStrength);
                surfaceData.smoothness = ormMap.g * _Smoothness;
                surfaceData.metallic = ormMap.b * _Metallic;
                surfaceData.emission = emission;
                surfaceData.alpha = albedo.a;

                // 4. Input Data
                InputData inputData = (InputData)0;
                inputData.positionWS = i.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = normalize(GetCameraPositionWS() - i.positionWS);
                //inputData.shadowCoord = GetShadowCoord(TransformWorldToShadowCoord(i.positionWS));
                inputData.bakedGI = SampleSH(normalWS);

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