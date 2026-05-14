Shader "Custom/TessellationDistance"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _HeightMap ("Height Map", 2D) = "gray" {}
        _Tess ("Tessellation Factor", Range(1, 64)) = 4
        _Displacement ("Displacement Amount", Range(0, 1)) = 0.1
        _MaxTesselationDistance ("Tessellation Distance", Float) = 20
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

            // Definição correta de Texturas para URP
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_HeightMap); SAMPLER(sampler_HeightMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _Tess;
                float _Displacement;
                float _MaxTesselationDistance;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct ControlPoint
            {
                float4 positionOS : INTERNAL_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            struct TessFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // --- Vertex Stage ---
            ControlPoint TessellationVertex(Attributes v)
            {
                ControlPoint o;
                o.positionOS = v.positionOS;
                o.uv = v.uv;
                o.normalOS = v.normalOS;
                return o;
            }

            // --- Tessellation Functions ---
            float CalcDistanceTessFactor(float3 worldPosition)
            {
                const float minDist = 2.0;
                float dist = distance(worldPosition, _WorldSpaceCameraPos);
                float factor = clamp(1.0 - (dist - minDist) / (_MaxTesselationDistance - minDist), 0.01, 1.0);
                return factor * _Tess;
            }

            TessFactors patchConstantFunc(InputPatch<ControlPoint, 3> patch)
            {
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
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            // --- Domain Shader ---
            [domain("tri")]
            Varyings domain(TessFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentric : SV_DomainLocation)
            {
                Varyings o;

                float3 posOS = patch[0].positionOS.xyz * barycentric.x + patch[1].positionOS.xyz * barycentric.y + patch[2].positionOS.xyz * barycentric.z;
                o.uv = patch[0].uv * barycentric.x + patch[1].uv * barycentric.y + patch[2].uv * barycentric.z;
                float3 normalOS = patch[0].normalOS * barycentric.x + patch[1].normalOS * barycentric.y + patch[2].normalOS * barycentric.z;

                // Displacement usando a macro do URP
                float height = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv, 0).r;
                posOS += normalOS * height * _Displacement;

                o.positionCS = TransformObjectToHClip(posOS);
                o.normalWS = TransformObjectToWorldNormal(normalOS);

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                return col;
            }
            ENDHLSL
        }
    }
}