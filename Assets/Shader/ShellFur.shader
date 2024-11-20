Shader "Custom/ShellFur"
{
    Properties
    {
        _FurMap("Fur Map", 2D) = "white" {}
        _FurBaseMap("Base Map for Fur (color/texture etc...)", 2D) = "white" {}
        [IntRange] _ShellCount("Total Shell Amount", Range(1, 100)) = 16
        _ShellLength("Shell Length/Step", Range(0.0, 1.0)) = 0.1
        _Density("Sample Density", Range(0.0, 1.0)) = 1.0
        _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.15
        _FurColor("Fur Color", Color) = (1,1,1,1)
        _Occlusion("Fuir Occlusion Factor", Range(0.0, 1.0)) = 0.1 
        _RimLightPow("Rim light power", Float) = 1.0
    }
    SubShader
    {
        
        Pass
        {
            Name "Main Pass"
            Tags 
            { 
                "RenderType" = "Opaque" 
                "LightMode" = "ForwardBase"
            }
            LOD 100
            Cull Off
            
            CGPROGRAM
            //
            //  The real shader starts here
            //  We need a Vertex shader and a Fragment shader
            //
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom

            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight

            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            // All the properties from exposed attributes
            int _ShellCount;
            float _ShellLength;
            float _Density;
            float _Thiccness;
            float _Curvature;
            float _DisplacementStength;
            float _ShellDirection;
            float _AlphaCutoff;
            float _Occlusion;
            float _RimLightPow;
            float4 _FurColor;

            sampler2D _FurMap;
            sampler2D _FurBaseMap;

            float4 _FurMap_ST;
            float4 _FurBaseMap_ST;

            // Other properties
            int _ShellInd;
            
            struct VertexData
            {
                float4 vertexPos : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct VertexToFrag
            {
                float4 pos : SV_POSITION;
                float2 alphaUV : TEXCOORD0;
                float2 baseUV : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float layer : TEXCOORD4;
                SHADOW_COORDS(5)
            };

            VertexData vert(VertexData v)
            {
                return v;
            }

            void AppendShellVertex(inout TriangleStream<VertexToFrag> stream, VertexData input, int index)
            {
                VertexToFrag output;

                float3 vertexInput = input.vertexPos.xyz;
                float3 normalInput = input.normal;

                float3 worldPos = mul(unity_ObjectToWorld, vertexInput);
                float3 normalWorld = normalize(UnityObjectToWorldNormal(normalInput));

                float3 displaceWorldPos = worldPos + normalWorld * (_ShellLength * index);
                float4 clipPos = UnityObjectToClipPos(displaceWorldPos);

                output.worldPos = displaceWorldPos;
                output.pos = clipPos;
                output.normal = normalWorld;
                output.alphaUV = TRANSFORM_TEX(input.uv, _FurMap);
                output.baseUV = TRANSFORM_TEX(input.uv, _FurBaseMap);
                output.layer = (float)index / _ShellCount;
                
                TRANSFER_SHADOW(output)

                stream.Append(output);
            }

            [maxvertexcount(40)]
            void geom(triangle VertexData input[3], inout TriangleStream<VertexToFrag> stream)
            {
                for (int i = 0; i < _ShellCount; i++)
                {
                    for (int j = 0; j < 3; j++)
                    {
                        AppendShellVertex(stream, input[j], i);
                    }
                    stream.RestartStrip();
                }
            }

            float4 frag(VertexToFrag f) : SV_Target
            {
                float4 sampleFur = tex2D(_FurMap, f.alphaUV * _Density);
                float4 sampleTex = tex2D(_FurBaseMap, f.baseUV);

                float alpha = sampleFur.r * (1.0f - f.layer);
                // Making fur strands darker and thinner deeper it goes
                if (f.layer > 0.0f && alpha.r < _AlphaCutoff) discard;

                float4 color = _FurColor * sampleTex;

                // Lighting output with half-lambert shading
                float ndotl = DotClamped(f.normal, _WorldSpaceLightPos0) * 0.5f + 0.5f;
                ndotl = ndotl * ndotl;

                // Darkening roots
                float occlusionFactor = lerp(1.0 - _Occlusion, 1.0, f.layer);

                // Receiving shadows
                half shadow = SHADOW_ATTENUATION(f);
                float3 viewDir = WorldSpaceViewDir(f.pos);
                float light = saturate(dot(normalize(_WorldSpaceLightPos0), f.normal)) * 0.5 + 0.5;
                half rim = pow(1.0 - saturate(dot(normalize(viewDir), f.normal)), _RimLightPow);
                color *= (light + rim) * _LightColor0 * shadow + float4( ShadeSH9(float4(f.normal, 1)), 1.0);
                
                return float4(color * occlusionFactor);
            }
            ENDCG
        }

        Pass
        {
            Name "Shadow"
            Tags 
            { 
                "LightMode" = "ShadowCaster"
            }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            CGPROGRAM
            //
            //  The real shader starts here
            //  We need a Vertex shader and a Fragment shader
            //
            #pragma vertex vert
            #pragma fragment fragShadow
            #pragma geometry geom

            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            // All the properties from exposed attributes
            int _ShellCount;
            float _ShellLength;
            float _Density;
            float _Thiccness;
            float _Curvature;
            float _DisplacementStength;
            float _ShellDirection;
            float _AlphaCutoff;
            float _Occlusion;
            float4 _FurColor;

            sampler2D _FurMap;
            sampler2D _FurBaseMap;

            float4 _FurMap_ST;
            float4 _FurBaseMap_ST;

            // Other properties
            int _ShellInd;
            
            struct VertexData
            {
                float4 vertexPos : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct VertexToFrag
            {
                float4 pos : SV_POSITION;
                float2 alphaUV : TEXCOORD0;
                float2 baseUV : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float layer : TEXCOORD4;
            };

            VertexData vert(VertexData v)
            {
                return v;
            }

            void AppendShellVertex(inout TriangleStream<VertexToFrag> stream, VertexData input, int index)
            {
                VertexToFrag output;

                float3 vertexInput = input.vertexPos.xyz;
                float3 normalInput = input.normal;

                float3 worldPos = mul(unity_ObjectToWorld, vertexInput);
                float3 normalWorld = normalize(UnityObjectToWorldNormal(normalInput));

                float3 displaceWorldPos = worldPos + normalWorld * (_ShellLength * index);

                // Get shadow position in clip space
                float4 clipPos = UnityApplyLinearShadowBias(UnityObjectToClipPos(displaceWorldPos));

                output.worldPos = displaceWorldPos;
                output.pos = clipPos;
                output.normal = normalWorld;
                output.alphaUV = TRANSFORM_TEX(input.uv, _FurMap);
                output.baseUV = TRANSFORM_TEX(input.uv, _FurBaseMap);
                output.layer = (float)index / _ShellCount;

                stream.Append(output);
            }

            [maxvertexcount(60)]
            void geom(triangle VertexData input[3], inout TriangleStream<VertexToFrag> stream)
            {
                for (int i = 0; i < _ShellCount; i++)
                {
                    for (int j = 0; j < 3; j++)
                    {
                        AppendShellVertex(stream, input[j], i);
                    }
                    stream.RestartStrip();
                }
            }

            float4 fragShadow(VertexToFrag f) : SV_Target
            {
                float4 sampleFur = tex2D(_FurMap, f.alphaUV * _Density);

                float alpha = sampleFur.r * (1.0f - f.layer);
                // Making fur strands darker and thinner deeper it goes
                if (f.layer > 0.0f && alpha.r < _AlphaCutoff) discard;

                SHADOW_CASTER_FRAGMENT(f)
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
