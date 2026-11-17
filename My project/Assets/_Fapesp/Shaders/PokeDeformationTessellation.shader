Shader "Custom/Poke_Deform_Tessellated"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainTexture] _NormalMap("Normal Map", 2D) = "white" {}
        _NormalScale ("Normal Scale", Float) = 1
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        
        [Header(Tessellation Settings)]
        _TessellationFactor ("Max Subdivisions", Range(1, 64)) = 24
        _TessellationMargin ("Extra Tessellation Margin", Float) = 0.2
        
        [Header(Deformation Settings)]
        _CapsulePointA ("Capsule Point A (Tip)", Vector) = (0,0,0)
        _CapsulePointB ("Capsule Point B (Base)", Vector) = (0,0,0)
        _CapsuleRadius ("Core Radius", Float) = 0.1
        _DeformFalloff ("Falloff Radius (Area)", Float) = 0.8
        _DeformMultiplier ("Push Multiplier", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma target 4.6
            #pragma vertex tessVert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv1: TEXCOORD1;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct ControlPoint
            {
                float4 positionOS : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            struct Varyings
            {
                float4 positionHCS              : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                float3 positionWS               : TEXCOORD1;
                float3 normalWS                 : TEXCOORD2;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
                float4 fogFactorAndVertexLight  : TEXCOORD4;
                float3 tangentWS                : TEXCOORD5;
                float3 bitangentWS              : TEXCOORD6;
                float2 uv1                      : TEXCOORD7;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _NormalScale;
                float _Smoothness;
                float _TessellationFactor;
                float _TessellationMargin;
                float3 _CapsulePointA;
                float3 _CapsulePointB;
                float _CapsuleRadius;
                float _DeformFalloff;
                float _DeformMultiplier;
            CBUFFER_END
            
            float3 GetViewDirectionFromPosition(float3 positionWS) {
                return normalize(GetCameraPositionWS() - positionWS);
            }
            
            float4 GetShadowCoord(float3 positionWS, float4 positionCS) {
            #if SHADOWS_SCREEN
                return ComputeScreenPos(positionCS);
            #else
                return TransformWorldToShadowCoord(positionWS);
            #endif
            }

            // Calculates radial distance perpendicular to the tool axis + forward tip distance
            float ToolDistance(float3 tip, float3 basePt, float radius, float3 pos)
            {
                float3 axis = basePt - tip;
                float axisLenSq = dot(axis, axis);
                
                if (axisLenSq < 0.00001)
                    return distance(pos, tip) - radius;

                float3 tipToPos = pos - tip;
                // Project onto the infinite line behind the tip (h >= 0 means behind the tip along the shaft)
                float h = max(0.0, dot(tipToPos, axis) / axisLenSq);
                // Clamp to segment [0, 1] so the tool has a finite shaft length
                h = saturate(h);
                float3 closestPoint = tip + h * axis;
                
                return distance(pos, closestPoint) - radius;
            }

            ControlPoint tessVert(Attributes IN)
            {
                ControlPoint OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                OUT.positionOS = IN.positionOS;
                OUT.uv = IN.uv;
                OUT.uv1 = IN.uv1;
                OUT.normalOS = IN.normalOS;
                OUT.tangentOS = IN.tangentOS;
                return OUT;
            }

            float CalcEdgeTessFactor(float3 posWS0, float3 posWS1)
            {
                float3 edgeMid = (posWS0 + posWS1) * 0.5;
                float d0 = ToolDistance(_CapsulePointA, _CapsulePointB, _CapsuleRadius, posWS0);
                float d1 = ToolDistance(_CapsulePointA, _CapsulePointB, _CapsuleRadius, posWS1);
                float dMid = ToolDistance(_CapsulePointA, _CapsulePointB, _CapsuleRadius, edgeMid);

                float minDist = min(min(d0, d1), dMid);

                float totalRange = max(0.001, _DeformFalloff + _TessellationMargin);
                float factor = 1.0 - smoothstep(0.0, totalRange, minDist);
                return lerp(1.0, _TessellationFactor, factor);
            }

            TessellationFactors patchConstantFunc(InputPatch<ControlPoint, 3> patch)
            {
                TessellationFactors f;

                float3 p0 = TransformObjectToWorld(patch[0].positionOS.xyz);
                float3 p1 = TransformObjectToWorld(patch[1].positionOS.xyz);
                float3 p2 = TransformObjectToWorld(patch[2].positionOS.xyz);

                f.edge[0] = CalcEdgeTessFactor(p1, p2);
                f.edge[1] = CalcEdgeTessFactor(p2, p0);
                f.edge[2] = CalcEdgeTessFactor(p0, p1);
                f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0;

                return f;
            }

            [domain("tri")]
            [outputcontrolpoints(3)]
            [outputtopology("triangle_cw")]
            [partitioning("fractional_odd")]
            [patchconstantfunc("patchConstantFunc")]
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            [domain("tri")]
            Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 bary : SV_DomainLocation)
            {
                Attributes IN;
                UNITY_SETUP_INSTANCE_ID(patch[0]);
                UNITY_TRANSFER_INSTANCE_ID(patch[0], IN);

                #define BARYCENTRIC_INTERPOLATE(fieldName) \
                    patch[0].fieldName * bary.x + \
                    patch[1].fieldName * bary.y + \
                    patch[2].fieldName * bary.z

                IN.positionOS = BARYCENTRIC_INTERPOLATE(positionOS);
                IN.uv         = BARYCENTRIC_INTERPOLATE(uv);
                IN.uv1        = BARYCENTRIC_INTERPOLATE(uv1);
                IN.normalOS   = normalize(BARYCENTRIC_INTERPOLATE(normalOS));
                IN.tangentOS  = BARYCENTRIC_INTERPOLATE(tangentOS);

                Varyings output = (Varyings)0;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
                
                // Distance from the tool capsule
                float dist = ToolDistance(_CapsulePointA, _CapsulePointB, _CapsuleRadius, posWS);

                if (dist < _DeformFalloff)
                {
                    float falloff = max(0.0001, _DeformFalloff);
                    // Smooth bell-like falloff from 0 at outer edge to 1 at the tool core
                    float t = saturate(1.0 - (max(0.0, dist) / falloff));
                    float weight = t * t * (3.0 - 2.0 * t); // Smoothstep curve

                    // Calculate how deep the tool tip has penetrated past this vertex along the surface normal
                    float3 tipToVert = posWS - _CapsulePointA;
                    // Push depth is how far behind the tip the vertex sits (plus the core radius)
                    float penetration = dot(tipToVert, normalWS) + _CapsuleRadius;

                    if (penetration > 0.0)
                    {
                        posWS -= normalWS * penetration * weight * _DeformMultiplier;
                    }
                }
                
                VertexPositionInputs posnInputs = GetVertexPositionInputs(TransformWorldToObject(posWS));
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                
                output.positionWS = posnInputs.positionWS;
                output.positionHCS = posnInputs.positionCS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = normalInputs.tangentWS;
                output.bitangentWS = normalInputs.bitangentWS;
                output.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                output.uv1 = TRANSFORM_TEX(IN.uv1, _BaseMap);
                
                #ifdef LIGHTMAP_ON
                    OUTPUT_LIGHTMAP_UV(IN.uv1, unity_LightmapST, output.lightmapUV);
                #else
                    OUTPUT_SH(output.normalWS, output.vertexSH);
                #endif
                
                float fogFactor = ComputeFogFactor(output.positionHCS.z);
                float3 vertexLight = VertexLighting(output.positionWS, output.normalWS);
                output.fogFactorAndVertexLight = float4(fogFactor, vertexLight);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalScale);
                float3x3 tbn = float3x3(input.tangentWS, input.bitangentWS, input.normalWS);
                float3 normalWS = normalize(mul(normalTS, tbn));
                float3 viewDir = GetViewDirectionFromPosition(input.positionWS);
                
                InputData lightingInput = (InputData)0;
                lightingInput.positionWS = input.positionWS;
                lightingInput.normalWS = normalWS; 
                lightingInput.viewDirectionWS = viewDir;
                lightingInput.shadowCoord = GetShadowCoord(lightingInput.positionWS, input.positionHCS);
                lightingInput.fogCoord = input.fogFactorAndVertexLight.x;
                lightingInput.vertexLighting = input.fogFactorAndVertexLight.yzw;
                lightingInput.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, lightingInput.normalWS);
                lightingInput.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionHCS);
                lightingInput.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
                
                SurfaceData surface = (SurfaceData)0;
                surface.albedo = color.rgb;
                surface.alpha = color.a;
                surface.metallic = 0;
                surface.smoothness = _Smoothness;
                surface.normalTS = float3(0, 0, 1); 
                surface.occlusion = 1;
                surface.emission = half3(0, 0, 0);

                return UniversalFragmentPBR(lightingInput, surface);
            }
            ENDHLSL
        }
    }
}