Shader "Custom/Tessellation_Unlit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _HeightMap ("Height Map", 2D) = "gray" {}
        _Tess ("Tessellation Factor", Range(1, 64)) = 4
        _Displacement ("Displacement Amount", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            HLSLPROGRAM
            #pragma target // Necessário para suporte a Tessellation
            #pragma vertex TessellationVertex
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 positionCS : SV_POSITION;
            };

            struct ControlPoint
            {
                float4 positionOS : INTERNAL_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            sampler2D _MainTex;
            sampler2D _HeightMap;
            float _Tess;
            float _Displacement;

            // --- Vertex Stage ---
            ControlPoint TessellationVertex(Attributes v)
            {
                ControlPoint o;
                o.positionOS = v.positionOS;
                o.uv = v.uv;
                o.normalOS = v.normalOS;
                return o;
            }

            // --- Hull Shader (Define a quantidade de subdivisão) ---
            struct TessFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            TessFactors patchConstantFunc(InputPatch<ControlPoint, 3> patch)
            {
                TessFactors f;
                f.edge[0] = _Tess;
                f.edge[1] = _Tess;
                f.edge[2] = _Tess;
                f.inside = _Tess;
                return f;
            }

            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [patchconstantfunc("patchConstantFunc")]
            [outputcontrolpoints(3)]
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            // --- Domain Shader (Onde a mágica acontece) ---
            [domain("tri")]
            Varyings domain(TessFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentric : SV_DomainLocation)
            {
                Varyings o;

                // Interpolação de posição, UV e normal
                float3 posOS = patch[0].positionOS.xyz * barycentric.x + patch[1].positionOS.xyz * barycentric.y + patch[2].positionOS.xyz * barycentric.z;
                o.uv = patch[0].uv * barycentric.x + patch[1].uv * barycentric.y + patch[2].uv * barycentric.z;
                float3 normalOS = patch[0].normalOS * barycentric.x + patch[1].normalOS * barycentric.y + patch[2].normalOS * barycentric.z;

                // Aplica o Displacement baseado no HeightMap
                float height = tex2Dlod(_HeightMap, float4(o.uv, 0, 0)).r;
                posOS += normalOS * height * _Displacement;

                o.positionCS = TransformObjectToHClip(posOS);
                o.normalWS = TransformObjectToWorldNormal(normalOS);

                return o;
            }

            // --- Fragment Shader ---
            half4 frag(Varyings i) : SV_Target
            {
                half4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDHLSL
        }
    }
}