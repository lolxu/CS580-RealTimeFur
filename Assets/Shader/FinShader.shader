Shader "Custom/FinShader"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _FurTipColor("Fur Tip Color", Color) = (1, 1, 1, 1)
        _BladeTexture("Blade Texture", 2D) = "white" {}
        
        _BladeWidthMin("Blade Minimum Width", Range(0, 5)) = 0.015
        _BladeWidthMax("Blade Maximum Width", Range(0, 5)) = 0.06
        _BladeHeightMin("Blade Minimum Height", Range(0, 5)) = 0.1
        _BladeHeightMax("Blade Maximum Height", Range(0, 5)) = 0.2
        
        _BladeSegments("Blade Segments", Int) = 3
		_BladeBendDistance("Blade Forward Amount", Float) = 0.38
		_BladeBendCurve("Blade Curvature Amount", Range(1, 4)) = 2
    	
    	_BendDelta("Bend Variation", Range(0, 1)) = 0.2
    	
    	_TessellationFurDistance("Tessellation Fur Distance", Range(0.01, 2)) = 0.1

    	_FurMap("Fur Visibility Map", 2D) = "white" {}
		_FurThreshold("Fur Visibility Threshold", Range(-0.1, 1)) = 0.5
		_FurFalloff("Fur Visibility Fade-In Falloff", Range(0, 0.5)) = 0.05
    	
    	_WindMap("Wind Offset Map", 2D) = "bump" {}
		_WindVelocity("Wind Velocity", Vector) = (1, 0, 0, 0)
		_WindFrequency("Wind Pulse Frequency", Range(0, 1)) = 0.01
    	
    	_ShadowStrength("Shadow Strength", Range(0, 1)) = 0.5  // Lower value = less intense shadows
        _ShadowAmbient("Shadow Ambient", Range(0, 1)) = 0.2
    	
    	_FurDirection("Base fur move direction", Vector) = (1.0, 1.0, 1.0)
    	
    	// Fur interactions
    	_InteractionPoint("Interaction Point", Vector) = (0, -9999, 0, 0)
		_InteractionRadius("Interaction Radius", float) = 0.0
    	_InteractionStrength("Interaction Strength", float) = 0.0
    }
    SubShader
    {		
    	Tags
		{	
			"RenderType" = "Opaque"
			"Queue" = "Geometry" 
		}
		LOD 100
		Cull Off
		
		Pass
		{
			Name "Main Pass"
			Tags
			{
				"LightMode" = "ForwardBase" 
				"IgnoreProjection" = "True"
			}
			ZWrite On
			
			CGPROGRAM
				#include "UnityCG.cginc"
				#include "UnityPBSLighting.cginc"
				#include "AutoLight.cginc"
				
				#pragma require geometry
				#pragma require tessellation tessHW

				#pragma fragment frag

				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
				#pragma multi_compile _ _SHADOWS_SOFT

    			#define UNITY_PI 3.14159265359f
				#define UNITY_TWO_PI 6.28318530718f
				#define BLADE_SEGMENTS 4

				#pragma vertex geomVert
				#pragma hull hull
				#pragma domain domain
				#pragma	geometry geom

				#pragma multi_compile_fwdbase
				#pragma multi_compile_fog
					
				
			    float4 _BaseColor;
			    float4 _FurTipColor;
			    sampler2D _BladeTexture;

			    float _BladeWidthMin;
			    float _BladeWidthMax;
			    float _BladeHeightMin;
			    float _BladeHeightMax;

    			int _BladeSegments;
			    float _BladeBendDistance;
			    float _BladeBendCurve;

			    float _BendDelta;

			    float _TessellationFurDistance;

			    sampler2D _FurMap;
			    float4 _FurMap_ST;
			    float _FurThreshold;
			    float _FurFalloff;

			    sampler2D _WindMap;
			    float4 _WindMap_ST; 
			    float4 _WindVelocity;
			    float _WindFrequency;

			    float _ShadowStrength;
				float _ShadowAmbient;

				float3 _FurDirection;

				float4 _InteractionPoint;
				float _InteractionRadius;
				float _InteractionStrength;

    			// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
				// Extended discussion on this function can be found at the following link:
				// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
				// Returns a number in the 0...1 range.
				float rand(float3 co)
				{
					return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
				}

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

    			// Basic Vertex stuff...
				struct VertexInput
			    {
				    float4 vertex : POSITION;
		    		float3 normal : NORMAL;
		    		float4 tangent : TANGENT;
		    		float2 uv : TEXCOORD0;
			    };

    			struct VertexOutput
    			{
    				float4 vertex : SV_POSITION;
    				float3 normal : NORMAL;
    				float4 tangent : TANGENT;
    				float2 uv : TEXCOORD0;
    			};

    			// For Geometric shader and creating Fur
    			struct GeometricData
    			{
    				float4 pos : SV_POSITION;
    				float2 uv : TEXCOORD0;
    				float3 worldPos : TEXCOORD1;
    				float3 normal : TEXCOORD2;
    				SHADOW_COORDS(3)  // Add shadow coordinates
    			};

    			// Structs for tessellation
    			struct TessellationFactors
    			{
    				float edge[3] : SV_TessFactor;
    				float inside : SV_InsideTessFactor;
    			};

    			// Tesselation Vertex, just copies everything
    			VertexOutput tessVert(VertexInput vIn)
    			{
    				VertexOutput vOut;
    				vOut.vertex = vIn.vertex;
    				vOut.tangent = vIn.tangent;
    				vOut.normal = vIn.normal;
    				vOut.uv = vIn.uv;

    				return vOut;
    			}

    			// Geometric Shader things
				VertexOutput geomVert(VertexInput vIn)
    			{
    				VertexOutput vOut;
    				vOut.vertex = mul(unity_ObjectToWorld, vIn.vertex); // Transforms to world position
    				vOut.normal = UnityObjectToWorldNormal(vIn.normal);
    				vOut.tangent = vIn.tangent;
    				vOut.uv = TRANSFORM_TEX(vIn.uv, _FurMap);
    				
    				return vOut;
    			}

    			// Tessleation Shader stuff

    			// Tessellation factor for an edge based on viewer position
    			float tesselationEdgeFactor(VertexInput vIn_0, VertexInput vIn_1)
    			{
    				float3 v0 = vIn_0.vertex.xyz;
    				float3 v1 = vIn_1.vertex.xyz;
    				float edgeLength = distance(v0, v1);

    				float result = edgeLength / _TessellationFurDistance;

    				return result;
    			}

    			// The patch constant function to create control points on the patch.
    			// Increasing tessellation factors adds new vertices on each edge.
    			TessellationFactors patchConstantFunc(InputPatch<VertexInput, 3> patch)
    			{
    				TessellationFactors fac;

    				fac.edge[0] = tesselationEdgeFactor(patch[1], patch[2]);
    				fac.edge[1] = tesselationEdgeFactor(patch[2], patch[0]);
    				fac.edge[2] = tesselationEdgeFactor(patch[0], patch[1]);
    				fac.inside = (fac.edge[0] + fac.edge[1] + fac.edge[2]) / 3.0f; // New vertex

    				return fac;
    			}

    			// The hull function for the tessellation shader.
    			// Operates on each patch, and outputs new control points for tessellation stages
    			[domain("tri")]
    			[outputcontrolpoints(3)]
    			[outputtopology("triangle_cw")]
    			[partitioning("integer")]
    			[patchconstantfunc("patchConstantFunc")]
    			VertexInput hull(InputPatch<VertexInput, 3> patch, uint id : SV_OutputControlPointID)
    			{
    				return patch[id];
    			}

    			// The graphics pipeline will generate new vertices

    			// The domain function for the tessellation shader
    			// It interpolates the properties of vertices to create new vertices
    			[domain("tri")]
				VertexOutput domain(TessellationFactors factors, OutputPatch<VertexInput, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
    			{
    				VertexInput vIn;
    				// barycentricCoordinates are weighted coordinates of each vertices
    				
    				#define INTERPOLATE(fieldname) vIn.fieldname = \
    					patch[0].fieldname * barycentricCoordinates.x + \
    					patch[1].fieldname * barycentricCoordinates.y + \
    					patch[2].fieldname * barycentricCoordinates.z;

    				INTERPOLATE(vertex)
    				INTERPOLATE(normal)
    				INTERPOLATE(tangent)
    				INTERPOLATE(uv)

    				return tessVert(vIn);
    			}

    			
    			// Transform to clip space for Geometric Shader
				GeometricData transformGeomToClip(float3 pos, float3 offset, float3x3 transformMat, float2 uv, float3 normal)
    			{
    				GeometricData gOut;
    				
					gOut.pos = UnityWorldToClipPos(pos + mul(transformMat, offset));
    				gOut.uv = uv;
    				gOut.worldPos = pos;
					gOut.normal = UnityObjectToWorldNormal(normal);

    				TRANSFER_SHADOW(gOut);
    				
    				return gOut;
    			}

    			// This is because at each segment, we add 2 vertices, and there is always 1 vertex at the tip
    			[maxvertexcount(BLADE_SEGMENTS * 2 + 1)] 
    			void geom(point VertexOutput input[1], inout TriangleStream<GeometricData> triangleStream)
    			{

					// Read from the Fur Map texture
    				float FurVisibility = tex2Dlod(_FurMap, float4(input[0].uv, 0, 0)).r;

    				// Check if the Fur needs to spawn or not
    				if (FurVisibility >= _FurThreshold)
    				{
    				
    					float3 pos = input[0].vertex.xyz;
    					float3 normal = input[0].normal;
    					float4 tangent = input[0].tangent;

    					float3 bitangent = cross(normal, tangent.xyz) * tangent.w;

    					float3x3 tangentToLocal = float3x3
    					(
    						tangent.x, bitangent.x, normal.x,
    						tangent.y, bitangent.y, normal.y,
    						tangent.z, bitangent.z, normal.z
						);

    					// Rotate around z-axis by some random amount
    					float seed = rand(pos);
    					float3x3 randRotateMat = angleAxis3x3(seed * UNITY_TWO_PI, float3(0, 0, 1.0f));

						// Calculate distance and direction to interaction point in world space
						float distToInteraction = distance(pos, _InteractionPoint.xyz);
						float interactionInfluence = 1 - saturate(distToInteraction / _InteractionRadius);
						interactionInfluence = smoothstep(0, 1, interactionInfluence);

						// Modify bend direction based on interaction
    					float3 bendAxis = normalize(_FurDirection);
						float bendAmount = lerp(_BendDelta, _BendDelta + _InteractionStrength, interactionInfluence);
						float3x3 randBendMat = angleAxis3x3(bendAmount * UNITY_PI, bendAxis);
    					
    					// Sampling from wind texture
    					float2 windUV = pos.xz * _WindMap_ST.xy + _WindMap_ST.zw + normalize(_WindVelocity.xzy) * _WindFrequency * _Time.y;
    					float2 windSample = (tex2Dlod(_WindMap, float4(windUV, 0, 0)).xy * 2 - 1) * length(_WindVelocity);

						// Wind Transforms
    					float3 windAxis = normalize(float3(windSample.x, windSample.y, 0));
    					float3x3 windMat = angleAxis3x3(UNITY_PI * windSample, windAxis);

    					// Transform matrices for base and tip of a blade
    					float3x3 baseTransformMat = mul(tangentToLocal, randRotateMat);
    					float3x3 tipTransformMat = mul(mul(mul(tangentToLocal, windMat), randBendMat), randRotateMat);
    					
						float falloff = smoothstep(_FurThreshold, _FurThreshold + _FurFalloff, FurVisibility);
    					
    					float width = lerp(_BladeWidthMin, _BladeWidthMax, rand(pos.xyz) * falloff);
    					float height = lerp(_BladeHeightMin, _BladeHeightMax, rand(pos.zyx) * falloff);
    					float forward = rand(pos.yyz) * _BladeBendDistance;

    					for (int i = 0; i <= _BladeSegments; i++)
    					{
    						float t = clamp(i / (float)_BladeSegments, 0.0f, 1.0f);
    						float3 offset = float3(width, pow(t, _BladeBendCurve) * forward, height * t);

    						float3x3 transformMat;
    						if (i == 0)
    						{
    							transformMat = baseTransformMat;
    						}
						    else
						    {
							    transformMat = tipTransformMat;
						    }

    						// Data for a single strip (for each 2 vertices)
    						triangleStream.Append(transformGeomToClip(pos, float3(offset.x, offset.y, offset.z), transformMat, float2(0, t), normal));
    						triangleStream.Append(transformGeomToClip(pos, float3(-offset.x, offset.y, offset.z), transformMat, float2(1, t), normal));
    						
    					}

    					triangleStream.RestartStrip();
    				}
    			}
				
				float4 frag(GeometricData gIn) : SV_Target
				{
					float4 color = tex2D(_BladeTexture, gIn.uv);
					if (color.z == 0 || color.a < 0.1f) discard;
					
	                color *= lerp(_BaseColor, _FurTipColor, gIn.uv.y);
	                
	                // Get shadow attenuation
	                float shadow = SHADOW_ATTENUATION(gIn);
	                
	                // Make shadows less intense by lerping with 1
	                shadow = lerp(1, shadow, _ShadowStrength);
	                
	                // Add ambient light to shadows
	                shadow = max(shadow, _ShadowAmbient);
	                
	                // Apply lighting - half lambert
					float light = pow(saturate(dot(normalize(_WorldSpaceLightPos0), gIn.normal)) * 0.5 + 0.5, 2.0);
					color *= (light) * _LightColor0 * shadow + float4(ShadeSH9(float4(gIn.normal, 1)), 1.0);
	                
	                return color;
				}
				
			ENDCG
		}

		// Shadow caster pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
			ZTest LEqual
            ColorMask 0
			
            
            CGPROGRAM
            #pragma vertex geomVert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment fragShadow
            #pragma multi_compile_shadowcaster
            #pragma target 4.6

            #include <AutoLight.cginc>

            #include "UnityCG.cginc"
            
            #define UNITY_PI 3.14159265359f
            #define UNITY_TWO_PI 6.28318530718f
            #define BLADE_SEGMENTS 4
            
		    float4 _BaseColor;
		    float4 _FurTipColor;
		    sampler2D _BladeTexture;

		    float _BladeWidthMin;
		    float _BladeWidthMax;
		    float _BladeHeightMin;
		    float _BladeHeightMax;

    		int _BladeSegments;
		    float _BladeBendDistance;
		    float _BladeBendCurve;

		    float _BendDelta;

		    float _TessellationFurDistance;

		    sampler2D _FurMap;
		    float4 _FurMap_ST;
		    float _FurThreshold;
		    float _FurFalloff;

		    sampler2D _WindMap;
		    float4 _WindMap_ST; 
		    float4 _WindVelocity;
		    float _WindFrequency;

            float3 _FurDirection;

            float4 _InteractionPoint;
			float _InteractionRadius;
			float _InteractionStrength;
            
            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            struct VertexOutput
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            struct GeometricData
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            // Structs for tessellation
    		struct TessellationFactors
    		{
    			float edge[3] : SV_TessFactor;
    			float inside : SV_InsideTessFactor;
    		};
            
            // Include your existing tessellation structs and functions here
            // (TessellationFactors, hull, domain functions, etc.)
            // ...

            float rand(float3 co)
            {
                return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
            }
            
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

    		// Tesselation Vertex, just copies everything
    		VertexOutput tessVert(VertexInput vIn)
    		{
    			VertexOutput vOut;
    			vOut.vertex = vIn.vertex;
    			vOut.tangent = vIn.tangent;
    			vOut.normal = vIn.normal;
    			vOut.uv = vIn.uv;

    			return vOut;
    		}

    		// Geometric Shader things
			VertexOutput geomVert(VertexInput vIn)
    		{
    			VertexOutput vOut;
    			vOut.vertex = mul(unity_ObjectToWorld, vIn.vertex); // Transforms to world position
    			vOut.normal = UnityObjectToWorldNormal(vIn.normal);
    			vOut.tangent = vIn.tangent;
    			vOut.uv = TRANSFORM_TEX(vIn.uv, _FurMap);
    			
    			return vOut;
    		}

    		// Tessleation Shader stuff

    		// Tessellation factor for an edge based on viewer position
    		float tesselationEdgeFactor(VertexInput vIn_0, VertexInput vIn_1)
    		{
    			float3 v0 = vIn_0.vertex.xyz;
    			float3 v1 = vIn_1.vertex.xyz;
    			float edgeLength = distance(v0, v1);

    			float result = edgeLength / _TessellationFurDistance;

    			return result;
    		}

    		// The patch constant function to create control points on the patch.
    		// Increasing tessellation factors adds new vertices on each edge.
    		TessellationFactors patchConstantFunc(InputPatch<VertexInput, 3> patch)
    		{
    			TessellationFactors fac;

    			fac.edge[0] = tesselationEdgeFactor(patch[1], patch[2]);
    			fac.edge[1] = tesselationEdgeFactor(patch[2], patch[0]);
    			fac.edge[2] = tesselationEdgeFactor(patch[0], patch[1]);
    			fac.inside = (fac.edge[0] + fac.edge[1] + fac.edge[2]) / 3.0f; // New vertex

    			return fac;
    		}

    		// The hull function for the tessellation shader.
    		// Operates on each patch, and outputs new control points for tessellation stages
    		[domain("tri")]
    		[outputcontrolpoints(3)]
    		[outputtopology("triangle_cw")]
    		[partitioning("integer")]
    		[patchconstantfunc("patchConstantFunc")]
    		VertexInput hull(InputPatch<VertexInput, 3> patch, uint id : SV_OutputControlPointID)
    		{
    			return patch[id];
    		}

    		// The graphics pipeline will generate new vertices

    		// The domain function for the tessellation shader
    		// It interpolates the properties of vertices to create new vertices
    		[domain("tri")]
			VertexOutput domain(TessellationFactors factors, OutputPatch<VertexInput, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
    		{
    			VertexInput vIn;
    			// barycentricCoordinates are weighted coordinates of each vertices
    			
    			#define INTERPOLATE(fieldname) vIn.fieldname = \
    				patch[0].fieldname * barycentricCoordinates.x + \
    				patch[1].fieldname * barycentricCoordinates.y + \
    				patch[2].fieldname * barycentricCoordinates.z;

    			INTERPOLATE(vertex)
    			INTERPOLATE(normal)
    			INTERPOLATE(tangent)
    			INTERPOLATE(uv)

    			return tessVert(vIn);
    		}

            
            GeometricData transformGeomToClipShadow(float3 pos, float3 offset, float2 uv, float3x3 transformMat)
            {
                GeometricData gOut;
                float3 worldPos = pos + mul(transformMat, offset);
                gOut.pos = UnityWorldToClipPos(worldPos);
                gOut.pos = UnityApplyLinearShadowBias(gOut.pos);
            	gOut.uv = uv;
            	
                return gOut;
            }
            
            [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
            void geom(point VertexOutput input[1], inout TriangleStream<GeometricData> triangleStream)
            {
                // Copy your existing geometry shader code here but use transformGeomToClipShadow
                // instead of transformGeomToClip
                // ...
            	// Read from the Fur Map texture
    				float FurVisibility = tex2Dlod(_FurMap, float4(input[0].uv, 0, 0)).r;

    				// Check if the Fur needs to spawn or not
    				if (FurVisibility >= _FurThreshold)
    				{
    				
    					float3 pos = input[0].vertex.xyz;
    					float3 normal = input[0].normal;
    					float4 tangent = input[0].tangent;

    					float3 bitangent = cross(normal, tangent.xyz) * tangent.w;

    					float3x3 tangentToLocal = float3x3
    					(
    						tangent.x, bitangent.x, normal.x,
    						tangent.y, bitangent.y, normal.y,
    						tangent.z, bitangent.z, normal.z
						);

    					// Rotate around z-axis by some random amount
    					float seed = rand(pos);
    					float3x3 randRotateMat = angleAxis3x3(seed * UNITY_TWO_PI, float3(0, 0, 1.0f));

						// Calculate distance and direction to interaction point in world space
						float distToInteraction = distance(pos, _InteractionPoint.xyz);
						float interactionInfluence = 1 - saturate(distToInteraction / _InteractionRadius);
						interactionInfluence = smoothstep(0, 1, interactionInfluence);

						// Modify bend direction based on interaction
    					float3 bendAxis = normalize(_FurDirection);
						float bendAmount = lerp(_BendDelta, _BendDelta + _InteractionStrength, interactionInfluence);
						float3x3 randBendMat = angleAxis3x3(bendAmount * UNITY_PI, bendAxis);
    					
    					// Sampling from wind texture
    					float2 windUV = pos.xz * _WindMap_ST.xy + _WindMap_ST.zw + normalize(_WindVelocity.xzy) * _WindFrequency * _Time.y;
    					float2 windSample = (tex2Dlod(_WindMap, float4(windUV, 0, 0)).xy * 2 - 1) * length(_WindVelocity);

						// Wind Transforms
    					float3 windAxis = normalize(float3(windSample.x, windSample.y, 0));
    					float3x3 windMat = angleAxis3x3(UNITY_PI * windSample, windAxis);

    					// Transform matrices for base and tip of a blade
    					float3x3 baseTransformMat = mul(tangentToLocal, randRotateMat);
    					float3x3 tipTransformMat = mul(mul(mul(tangentToLocal, windMat), randBendMat), randRotateMat);
    					
						float falloff = smoothstep(_FurThreshold, _FurThreshold + _FurFalloff, FurVisibility);
    					
    					float width = lerp(_BladeWidthMin, _BladeWidthMax, rand(pos.xyz) * falloff);
    					float height = lerp(_BladeHeightMin, _BladeHeightMax, rand(pos.zyx) * falloff);
    					float forward = rand(pos.yyz) * _BladeBendDistance;

    					for (int i = 0; i <= _BladeSegments; i++)
    					{
    						float t = i / (float)_BladeSegments;
    						float3 offset = float3(width * (1 - t), pow(t, _BladeBendCurve) * forward, height * t);

    						float3x3 transformMat;
    						if (i == 0)
    						{
    							transformMat = baseTransformMat;
    						}
						    else
						    {
							    transformMat = tipTransformMat;
						    }

    						// Data for a single strip (for each 2 vertices)
    						triangleStream.Append(transformGeomToClipShadow(pos, float3(offset.x, offset.y, offset.z), float2(0, t), transformMat));
    						triangleStream.Append(transformGeomToClipShadow(pos, float3(-offset.x, offset.y, offset.z), float2(1, t), transformMat));
    					}

    					triangleStream.RestartStrip();
    				}
            }
            
            float4 fragShadow(GeometricData i) : SV_Target
            {
                //SHADOW_CASTER_FRAGMENT(i)
				float4 color = tex2D(_BladeTexture, i.uv);
            	if (color.z == 0 || color.a < 0.1f) discard;
            	
            	return 0;
            }
            
            ENDCG
        }
	}
	FallBack "Diffuse"
}
