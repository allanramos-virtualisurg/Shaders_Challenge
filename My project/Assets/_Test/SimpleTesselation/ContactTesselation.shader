Shader "URP/ContactTessellation"
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
        [KeywordEnum(INTEGER, FRAC_EVEN, FRAC_ODD, POW2)] _PARTITIONING("Partition Algoritm", Float) = 0
        _Tess ("Max Tessellation Factor", Range(1, 64)) = 4
        _MaxTessDist ("Distance Culling", Float) = 20
        
        [Header(Contact Settings)]
        _ContactPos("Contact Position (World)", Vector) = (0,0,0,0)
        _ContactRadius("Contact Radius", Float) = 2.0
        _ContactFalloff("Contact Falloff", Range(0.01, 10)) = 1.0
        
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
            
            #pragma shader_feature_local _PARTITIONING_INTEGER _PARTITIONING_FRAC_EVEN _PARTITIONING_FRAC_ODD _PARTITIONING_POW2

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
                float contactWeight : TEXCOORD3; // Pass weight to domain
            };

            struct TessFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

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
                // Contact Vars
                float4 _ContactPos;
                float _ContactRadius;
                float _ContactFalloff;
            CBUFFER_END

            TEXTURE2D(_BaseMap);           SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);         SAMPLER(sampler_NormalMap);
            TEXTURE2D(_ORMMap);            SAMPLER(sampler_ORMMap);
            TEXTURE2D(_EmissionMap);       SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_HeightMap);         SAMPLER(sampler_HeightMap);

            ControlPoint TessellationVertex(Attributes v) {
                ControlPoint o;
                o.positionOS = v.positionOS;
                o.uv = v.uv;
                o.normalOS = v.normalOS;
                o.tangentOS = v.tangentOS;
                return o;
            }

            // --- NEW: Calculate Contact Weight ---
            float GetContactWeight(float3 worldPos) {
                float d = distance(worldPos, _ContactPos.xyz);
                // Sphere mask logic
                float weight = 1.0 - saturate((d - _ContactRadius) / _ContactFalloff);
                return weight;
            }

            float CalcContactTessFactor(float3 worldPos) {
                float dist = distance(worldPos, _WorldSpaceCameraPos);
                float distFactor = saturate(1.0 - (dist / _MaxTessDist));
                
                // Combine distance culling with contact weight
                float contactFactor = GetContactWeight(worldPos);
                
                // If weight is 0, tessellation is 1 (no subdivision)
                return max(1.0, contactFactor * distFactor * _Tess);
            }

            TessFactors patchConstantFunc(InputPatch<ControlPoint, 3> patch) {
                TessFactors f;
                float3 p0 = TransformObjectToWorld(patch[0].positionOS.xyz);
                float3 p1 = TransformObjectToWorld(patch[1].positionOS.xyz);
                float3 p2 = TransformObjectToWorld(patch[2].positionOS.xyz);

                float t0 = CalcContactTessFactor(p0);
                float t1 = CalcContactTessFactor(p1);
                float t2 = CalcContactTessFactor(p2);

                f.edge[0] = 0.5 * (t1 + t2);
                f.edge[1] = 0.5 * (t0 + t2);
                f.edge[2] = 0.5 * (t0 + t1);
                f.inside = (t0 + t1 + t2) / 3.0;
                return f;
            }

            [domain("tri")]
            #if defined(_PARTITIONING_INTEGER)
            [partitioning("integer")]
            #elif defined(_PARTITIONING_FRAC_EVEN)
            [partitioning("fractional_even")]
            #elif defined(_PARTITIONING_FRAC_ODD)
            [partitioning("fractional_odd")]
            #elif defined(_PARTITIONING_POW2)
            [partitioning("pow2")]
            #else 
            [partitioning("fractional_odd")]
            #endif
            [outputtopology("triangle_cw")]
            [patchconstantfunc("patchConstantFunc")]
            [outputcontrolpoints(3)]
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID) {
                return patch[id];
            }

            [domain("tri")]
            Varyings domain(TessFactors factors, OutputPatch<ControlPoint, 3> patch, float3 bary : SV_DomainLocation) {
                Varyings o;

                float3 posOS = patch[0].positionOS.xyz * bary.x + patch[1].positionOS.xyz * bary.y + patch[2].positionOS.xyz * bary.z;
                o.uv = patch[0].uv * bary.x + patch[1].uv * bary.y + patch[2].uv * bary.z;
                float3 normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
                float4 tangentOS = patch[0].tangentOS * bary.x + patch[1].tangentOS * bary.y + patch[2].tangentOS * bary.z;

                // Displacement only applied based on contact
                float3 worldPosRaw = TransformObjectToWorld(posOS);
                float weight = GetContactWeight(worldPosRaw);
                
                float height = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv, 0).r;
                
                // Displacement is multiplied by weight
                posOS += normalOS * (height * _Displacement * weight);

                o.positionWS = TransformObjectToWorld(posOS);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.normalWS = TransformObjectToWorldNormal(normalOS);
                o.tangentWS = float4(TransformObjectToWorldDir(tangentOS.xyz), tangentOS.w);
                o.contactWeight = weight;

                return o;
            }

            half4 frag(Varyings i) : SV_Target {
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv) * _BaseColor;
                half3 normalSample = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _BumpScale);
                half4 ormMap = SAMPLE_TEXTURE2D(_ORMMap, sampler_ORMMap, i.uv);
                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, i.uv).rgb * _EmissionColor.rgb;

                half3 bitangent = cross(i.normalWS, i.tangentWS.xyz) * i.tangentWS.w;
                half3x3 TBN = half3x3(i.tangentWS.xyz, bitangent, i.normalWS);
                half3 normalWS = normalize(mul(normalSample, TBN));

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo.rgb;
                surfaceData.occlusion = LerpWhiteTo(ormMap.r, _OcclusionStrength);
                surfaceData.smoothness = ormMap.g * _Smoothness;
                surfaceData.metallic = ormMap.b * _Metallic;
                surfaceData.emission = emission;
                surfaceData.alpha = albedo.a;

                InputData inputData = (InputData)0;
                inputData.positionWS = i.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = normalize(GetCameraPositionWS() - i.positionWS);
                inputData.bakedGI = SampleSH(normalWS);

                return UniversalFragmentPBR(inputData, surfaceData);
            }
            ENDHLSL
        }
    }
}