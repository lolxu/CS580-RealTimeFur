Shader "Custom/ShellFur"
{
    Properties
    {
        _FurMap("Fur Map", 2D) = "white" {}
        [IntRange] _ShellCount("Total Shell Amount", Range(1, 100)) = 16
        _ShellLength("Shell Length/Step", Range(0.0, 1.0)) = 0.1
        _Density("Density", Range(0.0, 100.0)) = 100.0
        _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.15
        _FurColor("Fur Color", Color) = (1,1,1,1)
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
            ZWrite On
            Cull Back
            
            CGPROGRAM
            //
            //  The real shader starts here
            //  We need a Vertex shader and a Fragment shader
            //
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom

            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            // All the properties from exposed attributes
            int _ShellCount;
            float _ShellLength;
            float _Density;
            float _NoiseMin;
            float _NoiseMax;
            float _Thiccness;
            float _Curvature;
            float _DisplacementStength;
            float _ShellDirection;
            float _AlphaCutoff;
            float4 _FurColor;

            Texture2D _FurMap;
            SamplerState sampler_FurMap;

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
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float layer : TEXCOORD3;
            };

            float noise(uint seed)
            {
                seed = (seed << 13U) ^ seed;
                seed = seed * (seed * seed * 15731U + 0x789221U) + 0x1376312589U;
                return float(seed & uint(0x7fffffffU)) / float(0x7fffffffU);
            }

            VertexData vert(VertexData v)
            {
                /*
                VertexToFrag result;
    
                // Goes from 0 to 1 (normalized with number of shells)
                float shellHeight = (float)_ShellInd / (float)_ShellCount;

                // Extruding the vertices by normal and shell length
                v.vertexPos.xyz += v.normal.xyz * _ShellLength * shellHeight;

                // Transforming the normal to world (only rotations...)
                result.normal = normalize(UnityObjectToWorldNormal(v.normal));

                float curve = pow(shellHeight, _Curvature);
                
                
                result.worldPos = mul(unity_ObjectToWorld, v.vertexPos);
                result.pos = UnityObjectToClipPos(v.vertexPos); // To clip space as default
                result.uv = v.uv;
                */
                
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
                output.uv = input.uv;
                output.layer = (float)index / _ShellCount;

                stream.Append(output);
            }

            [maxvertexcount(30)]
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
                float4 furColor = _FurMap.Sample(sampler_FurMap, f.uv);
                
                if (f.layer > 0.0f && furColor.r < _AlphaCutoff) discard;

                // Lighting output with half-lambert shading
                float ndotl = DotClamped(f.normal, _WorldSpaceLightPos0) * 0.5f + 0.5f;
                ndotl = ndotl * ndotl;
                
                return float4(_FurColor * ndotl);
            }
            ENDCG
        }

        Pass
        {
            Name "Shadows"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            CGPROGRAM

            
            ENDCG
        }
    }
    FallBack "Diffuse"
}
