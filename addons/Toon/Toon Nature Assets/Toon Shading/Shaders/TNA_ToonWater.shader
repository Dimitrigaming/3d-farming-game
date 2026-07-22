Shader "Toon/TNA_ToonWater"
{
    Properties
    {
		_DepthGradientShallow("Depth Gradient Shallow", Color) = (0.18, 0.6, 0.75, 0.6)

		_DepthGradientDeep("Depth Gradient Deep", Color) = (0, 0.3, 0.8, 0.6)

		_DepthMaxDistance("Depth Maximum Distance", Float) = 1

		_FoamColor("Foam Color", Color) = (1,1,1,1)

		_SurfaceNoise("Surface Noise", 2D) = "white" {}

		_SurfaceNoiseScroll("Surface Noise Scroll Amount", Vector) = (0.05, 0.05, 0, 0)

		_SurfaceNoiseCutoff("Surface Noise Cutoff", Range(0, 1)) = 0.7

		_SurfaceDistortion("Surface Distortion", 2D) = "white" {}	

		_SurfaceDistortionAmount("Surface Distortion Amount", Range(0, 1)) = 0.4

		_FoamMaxDistance("Foam Maximum Distance", Float) = 0.4

		_FoamMinDistance("Foam Minimum Distance", Float) = 0.25	
    }
    SubShader
    {
		Tags
		{
			"Queue" = "Transparent"
		}

        Pass
        {
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off

            CGPROGRAM
			#define SMOOTHSTEP_AA 0.1

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

			float4 alphaBlend(float4 top, float4 bottom)
			{
				float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
				float alpha = top.a + bottom.a * (1 - top.a);

				return float4(color, alpha);
			}

            struct appdata
            {
                float4 vertex : POSITION;
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;	
				float2 noiseUV : TEXCOORD0;
				float2 distortUV : TEXCOORD1;
				float4 screenPosition : TEXCOORD2;
				float3 viewNormal : NORMAL;
            };

			sampler2D _SurfaceNoise;
			float4 _SurfaceNoise_ST;

			sampler2D _SurfaceDistortion;
			float4 _SurfaceDistortion_ST;

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPosition = ComputeScreenPos(o.vertex);
				o.distortUV = TRANSFORM_TEX(v.uv, _SurfaceDistortion);
				o.noiseUV = TRANSFORM_TEX(v.uv, _SurfaceNoise);
				o.viewNormal = COMPUTE_VIEW_NORMAL;

                return o;
            }

			float4 _DepthGradientShallow;
			float4 _DepthGradientDeep;
			float4 _FoamColor;

			float _DepthMaxDistance;
			float _FoamMaxDistance;
			float _FoamMinDistance;
			float _SurfaceNoiseCutoff;
			float _SurfaceDistortionAmount;

			float2 _SurfaceNoiseScroll;

			sampler2D _CameraDepthTexture;
			sampler2D _CameraNormalsTexture;

            float4 frag (v2f i) : SV_Target
            {
				float existingDepth01 = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPosition)).r;
				float existingDepthLinear = LinearEyeDepth(existingDepth01);

				float depthDifference = existingDepthLinear - i.screenPosition.w;

				float waterDepthDifference01 = saturate(depthDifference / _DepthMaxDistance);
				float4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, waterDepthDifference01);
				
				float3 existingNormal = tex2Dproj(_CameraNormalsTexture, UNITY_PROJ_COORD(i.screenPosition));
				
				float3 normalDot = saturate(dot(existingNormal, i.viewNormal));
				float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
				float foamDepthDifference01 = saturate(depthDifference / foamDistance);

				float surfaceNoiseCutoff = foamDepthDifference01 * _SurfaceNoiseCutoff;

				float2 distortSample = (tex2D(_SurfaceDistortion, i.distortUV).xy * 2 - 1) * _SurfaceDistortionAmount;

				float2 noiseUV = float2((i.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x) + distortSample.x, 
				(i.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y) + distortSample.y);
				float surfaceNoiseSample = tex2D(_SurfaceNoise, noiseUV).r;

				//float surfaceNoise = surfaceNoiseSample > surfaceNoiseCutoff ? 1 : 0;
				float surfaceNoise = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample);

				float4 surfaceNoiseColor = _FoamColor;
				surfaceNoiseColor.a *= surfaceNoise;

				return alphaBlend(surfaceNoiseColor, waterColor);
            }
            ENDCG
        }
    }
}