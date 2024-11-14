Shader "Custom/ShellFur"
{
//    Properties
//    {
//        _ShellCount ("Shell Count", Int) = 0
//        _ShellLength ("Shell Length", Float) = 0.0
//        _Density ("Shell Strand Density", Float) = 0.0
//        _NoiseMin ("Min Noise for Generation", Float) = 0.0
//        _NoiseMax ("Max Noise for Generation", Float) = 0.5
//        _Thiccness ("Thickness of Fur", Float) = 0.0
//        _FurColor ("Fur Color", Color) = (1,1,1,1)
//    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "LightMode" = "ForwardBase"
        }
        LOD 200
        Cull Off
        
        Pass
        {
            CGPROGRAM
            //
            //  The real shader starts here
            //  We need a Vertex shader and a Fragment shader
            //
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            // All the properties from exposed attributes
            int _ShellCount;
            float _ShellLength;
            float _Density;
            float _NoiseMin;
            float _NoiseMax;
            float _Thiccness;
            float4 _FurColor;

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
            };

            

            VertexToFrag vert(VertexData v)
            {
                VertexToFrag result;

                // Goes from 0 to 1 (normalized with number of shells)
                float shellHeight = (float)_ShellInd / (float)_ShellCount;

                // Extruding the vertices by normal and shell length
                v.vertexPos.xyz += v.normal.xyz * _ShellLength * shellHeight;

                // Transforming the normal to world (only rotations...)
                result.normal = normalize(UnityObjectToWorldNormal(v.normal));
                result.worldPos = mul(unity_ObjectToWorld, v.vertexPos);
                result.pos = UnityObjectToClipPos(v.vertexPos); // To clip space as default
                result.uv = v.uv;
                
                return result;
            }

            float4 frag(VertexToFrag f) : SV_Target
            {
                // Creating more fur strands with multiplication of density
                float2 denseUV = f.uv * _Density;

                // Convert 0-1 uv to -1 to 1
                float2 nUV = frac(denseUV) * 2 - 1;

                float distFromCenter = length(nUV);
                
                
                return _FurColor;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
