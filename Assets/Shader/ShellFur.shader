Shader "Custom/ShellFur"
{
    Properties
    {
        _FurMap("Fur Map", 2D) = "white" {}
        _FurBaseMap("Base Map for Fur (color/texture etc...)", 2D) = "white" {}
        [IntRange] _ShellCount("Total Shell Amount", Range(1, 100)) = 16
        _ShellLength("Shell Length/Step", Range(0.0, 0.1)) = 0.01
        _Density("Sample Density", Range(0.0, 1.0)) = 1.0
        _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.15
        _FurColor("Fur Color", Color) = (1,1,1,1)
        _Occlusion("Fuir Occlusion Factor", Range(0.0, 1.0)) = 0.1 
        _RimLightPow("Rim light power", Float) = 1.0
        _ShellDirection("Base shell move direction", Vector) = (1.0, 1.0, 1.0, 1.0)
        
        // Shadows
        _ShadowStrength("Shadow Strength", Range(0, 1)) = 0.5  // Lower value = less intense shadows
        _ShadowAmbient("Shadow Ambient", Range(0, 1)) = 0.2
        
        // Wind...
        _WindMap("Wind Map", 2D) = "white" {}
        _WindVelocity("Wind Velocity", Vector) = (1, 0, 0, 0)
		_WindFrequency("Wind Pulse Frequency", Range(0, 1)) = 0.01
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
            float _AlphaCutoff;
            float _Occlusion;
            float _RimLightPow;
            float4 _ShellDirection;
            float4 _FurColor;

            float _ShadowStrength;
            float _ShadowAmbient;

            sampler2D _FurMap;
            sampler2D _FurBaseMap;

            float4 _FurMap_ST;
            float4 _FurBaseMap_ST;

            sampler2D _WindMap;
            float4 _WindMap_ST;
            float4 _WindVelocity;
            float _WindFrequency;

            // Other properties
            int _ShellInd;
            
            struct VertexData
            {
                float4 vertexPos : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float2 uv3 : TEXCOORD2;
            };

            struct VertexToFrag
            {
                float4 pos : SV_POSITION;
                float2 alphaUV : TEXCOORD0;
                float2 baseUV : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float layer : TEXCOORD4;
                unityShadowCoord4 _ShadowCoord : TEXCOORD5;
                float3 viewDir : TEXCOORD6;
            };

            // Construct a rotation matrix that rotates around the provided axis, sourced from:
			// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
			float3x3 angleAxis3x3(float angle, float3 axis)
			{
				float c, s;
				sincos(angle, s, c);

				float t = 1 - c;
				float x = axis.x;
				float y = axis.y;
				float z = axis.z;

				return float3x3
				(
					t * x * x + c, t * x * y - s * z, t * x * z + s * y,
					t * x * y + s * z, t * y * y + c, t * y * z - s * x,
					t * x * z - s * y, t * y * z + s * x, t * z * z + c
				);
			}

            VertexData vert(VertexData v)
            {
                return v;
            }

            void AppendShellVertex(inout TriangleStream<VertexToFrag> stream, VertexData input, int index)
            {
                VertexToFrag output;

                float3 vertexInput = input.vertexPos.xyz;
                float3 normalInput = input.normal;

                float3 worldPos = mul(unity_ObjectToWorld, float4(vertexInput, 1.0f)).xyz;
                float3 normalWorld = normalize(UnityObjectToWorldNormal(normalInput));

                // Adding displacement
                float displaceFactor = pow((float)index / _ShellCount, _ShellDirection.w);

                // Sampling from wind texture
    			float2 windUV = input.vertexPos.xz * _WindMap_ST.xy + _WindMap_ST.zw + normalize(_WindVelocity.xzy) * _WindFrequency * _Time.y;
    			float2 windSample = (tex2Dlod(_WindMap, float4(windUV, 0, 0)).xy * 2 - 1) * length(_WindVelocity);

				// Wind Transforms
    			float3 windAxis = normalize(float3(windSample.x, windSample.y, 0));
    			float3x3 windMat = angleAxis3x3(UNITY_PI * windSample.x, windAxis) * ((float)index / _ShellCount);

                float3 disp = displaceFactor * (_ShellDirection.xyz + float3(input.uv2, input.uv3.x) * input.uv3.y);
                float3 shellMoveDir = mul(normalize(normalWorld + disp), windMat);
                
                float3 displaceWorldPos = worldPos + shellMoveDir * (_ShellLength * index);
                
                float4 clipPos = UnityWorldToClipPos(displaceWorldPos);

                output.pos = clipPos;
                output.normal = normalWorld;
                output.alphaUV = TRANSFORM_TEX(input.uv, _FurMap);
                output.baseUV = TRANSFORM_TEX(input.uv, _FurBaseMap);
                output.layer = (float)index / _ShellCount;
                output._ShadowCoord = ComputeScreenPos(clipPos);
                output.viewDir = WorldSpaceViewDir(input.vertexPos);
                
                stream.Append(output);
            }

            [maxvertexcount(53)]
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

                // Darkening roots
                float occlusionFactor = lerp(1.0 - _Occlusion, 1.0, f.layer);

                // Receiving shadows
                half shadow = SHADOW_ATTENUATION(f);

                // Make shadows less intense by lerping with 1
                shadow = lerp(1, shadow, _ShadowStrength);
	                
                // Add ambient light to shadows
                shadow = max(shadow, _ShadowAmbient);

                // Apply lighting - half lambert
                float light = pow(saturate(dot(normalize(_WorldSpaceLightPos0), f.normal)) * 0.5 + 0.5, 2.0);
                half rim = pow(1.0 - saturate(dot(normalize(f.viewDir), f.normal)), _RimLightPow);
                color *= (light + rim) * _LightColor0 * shadow + float4(ShadeSH9(float4(f.normal, 1)), 1.0);
                
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
            float _AlphaCutoff;
            float _Occlusion;
            float4 _ShellDirection;
            float4 _FurColor;

            sampler2D _FurMap;
            sampler2D _FurBaseMap;

            float4 _FurMap_ST;
            float4 _FurBaseMap_ST;

            sampler2D _WindMap;
            float4 _WindMap_ST;
            float4 _WindVelocity;
            float _WindFrequency;

            // Other properties
            int _ShellInd;
            
            struct VertexData
            {
                float4 vertexPos : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float2 uv3 : TEXCOORD2;
            };

            struct VertexToFrag
            {
                float4 pos : SV_POSITION;
                float2 alphaUV : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float layer : TEXCOORD2;
            };

            // Construct a rotation matrix that rotates around the provided axis, sourced from:
			// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
			float3x3 angleAxis3x3(float angle, float3 axis)
			{
				float c, s;
				sincos(angle, s, c);

				float t = 1 - c;
				float x = axis.x;
				float y = axis.y;
				float z = axis.z;

				return float3x3
				(
					t * x * x + c, t * x * y - s * z, t * x * z + s * y,
					t * x * y + s * z, t * y * y + c, t * y * z - s * x,
					t * x * z - s * y, t * y * z + s * x, t * z * z + c
				);
			}

            VertexData vert(VertexData v)
            {
                return v;
            }

            void AppendShellVertex(inout TriangleStream<VertexToFrag> stream, VertexData input, int index)
            {
                VertexToFrag output;

                float3 vertexInput = input.vertexPos.xyz;
                float3 normalInput = input.normal;

                float3 worldPos = mul(unity_ObjectToWorld, float4(vertexInput, 1.0f)).xyz;
                float3 normalWorld = normalize(UnityObjectToWorldNormal(normalInput));

                // Apply shell displacement
                float displaceFactor = pow((float)index / _ShellCount, _ShellDirection.w);

                // Sampling from wind texture
    			float2 windUV = input.vertexPos.xz * _WindMap_ST.xy + _WindMap_ST.zw + normalize(_WindVelocity.xzy) * _WindFrequency * _Time.y;
    			float2 windSample = (tex2Dlod(_WindMap, float4(windUV, 0, 0)).xy * 2 - 1) * length(_WindVelocity);

				// Wind Transforms
    			float3 windAxis = normalize(float3(windSample.x, windSample.y, 0));
    			float3x3 windMat = angleAxis3x3(UNITY_PI * windSample, windAxis) * ((float)index / _ShellCount);

                float3 disp = displaceFactor * (_ShellDirection.xyz + float3(input.uv2, input.uv3.x) * input.uv3.y);
                float3 shellMoveDir = mul(normalize(normalWorld + disp), windMat);
                
                float3 displaceWorldPos = worldPos + shellMoveDir * (_ShellLength * index);

                // Get shadow position in clip space
                float4 clipPos =  UnityWorldToClipPos(displaceWorldPos);

                output.pos = UnityApplyLinearShadowBias(clipPos);
                output.normal = normalWorld;
                output.alphaUV = TRANSFORM_TEX(input.uv, _FurMap);
                output.layer = (float)index / _ShellCount;

                stream.Append(output);
            }

            [maxvertexcount(50)]
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

                SHADOW_CASTER_FRAGMENT(f);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
