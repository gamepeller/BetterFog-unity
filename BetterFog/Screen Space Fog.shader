// Made with Amplify Shader Editor v1.9.0.2
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Screen Space Fog"
{
	Properties
	{
		_MainTex ( "Screen", 2D ) = "black" {}
		_FogNearColor("Fog Near Color", Color) = (0,0,0,0)
		_FogFarColor("Fog Far Color", Color) = (0,0,0,0)
		_HeightFadeStart("Height Fade Start", Range( -1000 , 1000)) = 0
		_DistanceMult("DistanceMult", Range( 0 , 1000)) = 1
		_HeightFadeEnd("Height Fade End", Range( 0 , 1000)) = 0
		_FalloffExponent("Falloff Exponent", Range( 0 , 10)) = 1
		_Levels("Levels", Range( 1 , 256)) = 1
		_DistanceFadeEnd("Distance Fade End", Float) = 1000
		_DistanceFadeStart("Distance Fade Start", Float) = 0
		[Toggle]_SyncUnityDefaultFogColor("Sync Unity Default Fog Color", Float) = 1
		_NoiseScale("Noise Scale", Range( 0 , 0.1)) = 0
		_NoiseMagnitude("Noise Magnitude", Range( 0 , 0.1)) = 0
		_WindDirection("Wind Direction", Vector) = (0,0,0,0)
		_WindSpeed("Wind Speed", Float) = 0
		[HideInInspector] _texcoord( "", 2D ) = "white" {}

	}

	SubShader
	{
		LOD 0

		
		
		ZTest Always
		Cull Off
		ZWrite Off

		
		Pass
		{ 
			CGPROGRAM 

			

			#pragma vertex vert_img_custom 
			#pragma fragment frag
			#pragma target 3.0
			#include "UnityCG.cginc"
			#include "UnityShaderVariables.cginc"


			struct appdata_img_custom
			{
				float4 vertex : POSITION;
				half2 texcoord : TEXCOORD0;
				
			};

			struct v2f_img_custom
			{
				float4 pos : SV_POSITION;
				half2 uv   : TEXCOORD0;
				half2 stereoUV : TEXCOORD2;
		#if UNITY_UV_STARTS_AT_TOP
				half4 uv2 : TEXCOORD1;
				half4 stereoUV2 : TEXCOORD3;
		#endif
				float4 ase_texcoord4 : TEXCOORD4;
			};

			uniform sampler2D _MainTex;
			uniform half4 _MainTex_TexelSize;
			uniform half4 _MainTex_ST;
			
			uniform float4 _FogNearColor;
			uniform float _SyncUnityDefaultFogColor;
			uniform float4 _FogFarColor;
			uniform float _Levels;
			UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
			uniform float4 _CameraDepthTexture_TexelSize;
			uniform float _DistanceFadeStart;
			uniform float _DistanceFadeEnd;
			uniform float _FalloffExponent;
			uniform float _DistanceMult;
			uniform float _HeightFadeStart;
			uniform float2 _WindDirection;
			uniform float _WindSpeed;
			uniform float _NoiseScale;
			uniform float _NoiseMagnitude;
			uniform float _HeightFadeEnd;
			inline float Dither8x8Bayer( int x, int y )
			{
				const float dither[ 64 ] = {
			 1, 49, 13, 61,  4, 52, 16, 64,
			33, 17, 45, 29, 36, 20, 48, 32,
			 9, 57,  5, 53, 12, 60,  8, 56,
			41, 25, 37, 21, 44, 28, 40, 24,
			 3, 51, 15, 63,  2, 50, 14, 62,
			35, 19, 47, 31, 34, 18, 46, 30,
			11, 59,  7, 55, 10, 58,  6, 54,
			43, 27, 39, 23, 42, 26, 38, 22};
				int r = y * 8 + x;
				return dither[r] / 64; // same # of instructions as pre-dividing due to compiler magic
			}
			
			float2 UnStereo( float2 UV )
			{
				#if UNITY_SINGLE_PASS_STEREO
				float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
				UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
				#endif
				return UV;
			}
			
			float3 InvertDepthDir72_g1( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			
			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			


			v2f_img_custom vert_img_custom ( appdata_img_custom v  )
			{
				v2f_img_custom o;
				float4 ase_clipPos = UnityObjectToClipPos(v.vertex);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord4 = screenPos;
				
				o.pos = UnityObjectToClipPos( v.vertex );
				o.uv = float4( v.texcoord.xy, 1, 1 );

				#if UNITY_UV_STARTS_AT_TOP
					o.uv2 = float4( v.texcoord.xy, 1, 1 );
					o.stereoUV2 = UnityStereoScreenSpaceUVAdjust ( o.uv2, _MainTex_ST );

					if ( _MainTex_TexelSize.y < 0.0 )
						o.uv.y = 1.0 - o.uv.y;
				#endif
				o.stereoUV = UnityStereoScreenSpaceUVAdjust ( o.uv, _MainTex_ST );
				return o;
			}

			half4 frag ( v2f_img_custom i ) : SV_Target
			{
				#ifdef UNITY_UV_STARTS_AT_TOP
					half2 uv = i.uv2;
					half2 stereoUV = i.stereoUV2;
				#else
					half2 uv = i.uv;
					half2 stereoUV = i.stereoUV;
				#endif	
				
				half4 finalColor;

				// ase common template code
				float2 uv_MainTex = i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				float4 tex2DNode2 = tex2D( _MainTex, uv_MainTex );
				float4 NearCol9 = _FogNearColor;
				float4 lerpResult14 = lerp( tex2DNode2 , NearCol9 , NearCol9.a);
				float4 FarCol18 = _FogFarColor;
				float4 lerpResult12 = lerp( tex2DNode2 , (( _SyncUnityDefaultFogColor )?( unity_FogColor ):( FarCol18 )) , (( _SyncUnityDefaultFogColor )?( unity_FogColor ):( FarCol18 )).a);
				float4 screenPos = i.ase_texcoord4;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float2 clipScreen113 = ase_screenPosNorm.xy * _ScreenParams.xy;
				float dither113 = Dither8x8Bayer( fmod(clipScreen113.x, 8), fmod(clipScreen113.y, 8) );
				float temp_output_95_0 = round( _Levels );
				float2 UV22_g3 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g3 = UnStereo( UV22_g3 );
				float2 break64_g1 = localUnStereo22_g3;
				float clampDepth69_g1 = SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g1 = ( 1.0 - clampDepth69_g1 );
				#else
				float staticSwitch38_g1 = clampDepth69_g1;
				#endif
				float3 appendResult39_g1 = (float3(break64_g1.x , break64_g1.y , staticSwitch38_g1));
				float4 appendResult42_g1 = (float4((appendResult39_g1*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g1 = mul( unity_CameraInvProjection, appendResult42_g1 );
				float3 temp_output_46_0_g1 = ( (temp_output_43_0_g1).xyz / (temp_output_43_0_g1).w );
				float3 In72_g1 = temp_output_46_0_g1;
				float3 localInvertDepthDir72_g1 = InvertDepthDir72_g1( In72_g1 );
				float4 appendResult49_g1 = (float4(localInvertDepthDir72_g1 , 1.0));
				float4 WorldPos22 = mul( unity_CameraToWorld, appendResult49_g1 );
				float Distance32 = _DistanceMult;
				float mulTime140 = _Time.y * _WindSpeed;
				float simplePerlin2D127 = snoise( ( ( _WindDirection * mulTime140 ) + (WorldPos22).xz )*_NoiseScale );
				simplePerlin2D127 = simplePerlin2D127*0.5 + 0.5;
				float temp_output_135_0 = ( simplePerlin2D127 * _NoiseMagnitude );
				float HeightFadeStart19 = ( _HeightFadeStart - ( temp_output_135_0 * 1000.0 ) );
				float HeightFadeLength28 = saturate( ( ( 1.0 / _HeightFadeEnd ) - temp_output_135_0 ) );
				float lerpResult13 = lerp( saturate( ( pow( (0.0 + (distance( WorldPos22 , float4( _WorldSpaceCameraPos , 0.0 ) ) - _DistanceFadeStart) * (1.0 - 0.0) / (_DistanceFadeEnd - _DistanceFadeStart)) , _FalloffExponent ) * Distance32 ) ) , 0.0 , saturate( ( ( WorldPos22.y - HeightFadeStart19 ) * HeightFadeLength28 ) ));
				float temp_output_77_0 = ( floor( ( temp_output_95_0 * lerpResult13 ) ) / temp_output_95_0 );
				dither113 = step( dither113, ( temp_output_95_0 * abs( ( temp_output_77_0 - lerpResult13 ) ) ) );
				float4 lerpResult15 = lerp( lerpResult14 , lerpResult12 , ( dither113 == 0.0 ? temp_output_77_0 : ( ceil( ( temp_output_95_0 * lerpResult13 ) ) / temp_output_95_0 ) ));
				

				finalColor = lerpResult15;

				return finalColor;
			} 
			ENDCG 
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	Fallback Off
}
/*ASEBEGIN
Version=19002
144;228.6667;2409.333;978.3334;2707.824;2449.837;1.3;True;False
Node;AmplifyShaderEditor.FunctionNode;3;-876.6508,-925.3665;Inherit;False;Reconstruct World Position From Depth;-1;;1;e7094bcbcc80eb140b2a3dbe6a861de8;0;0;1;FLOAT4;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;22;-507.1138,-940.9815;Inherit;False;WorldPos;-1;True;1;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;141;-1704.318,-2171.335;Inherit;False;Property;_WindSpeed;Wind Speed;13;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;131;-1717.831,-2069.104;Inherit;False;22;WorldPos;1;0;OBJECT;;False;1;FLOAT4;0
Node;AmplifyShaderEditor.Vector2Node;139;-1486.998,-2373.332;Inherit;False;Property;_WindDirection;Wind Direction;12;0;Create;True;0;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.SimpleTimeNode;140;-1507.318,-2154.335;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;142;-1311.318,-2160.335;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ComponentMaskNode;133;-1478.831,-2067.104;Inherit;False;True;False;True;False;1;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;130;-1611.17,-1914.258;Inherit;False;Property;_NoiseScale;Noise Scale;10;0;Create;True;0;0;0;False;0;False;0;0;0;0.1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;143;-1194.318,-2034.335;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;136;-1223.358,-1849.654;Inherit;False;Property;_NoiseMagnitude;Noise Magnitude;11;0;Create;True;0;0;0;False;0;False;0;0;0;0.1;0;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;127;-1067.205,-1993.445;Inherit;False;Simplex2D;True;False;2;0;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;20;-1177.397,-1617.685;Inherit;False;Property;_HeightFadeEnd;Height Fade End;4;0;Create;True;0;0;0;False;0;False;0;0;0;1000;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;135;-832.8553,-1953.764;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;21;-1139.481,-1355.445;Inherit;False;Property;_HeightFadeStart;Height Fade Start;2;0;Create;True;0;0;0;False;0;False;0;0;-1000;1000;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;146;-851.6092,-1443.355;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;1000;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;23;-888.5329,-1634.063;Inherit;False;2;0;FLOAT;1;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;145;-724.7881,-1376.951;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;138;-725.6675,-1639.379;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.WorldSpaceCameraPos;60;-2161.16,514.923;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.GetLocalVarNode;38;-2114.616,419.2934;Inherit;False;22;WorldPos;1;0;OBJECT;;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;117;-1857.568,654.3331;Inherit;False;Property;_DistanceFadeEnd;Distance Fade End;7;0;Create;True;0;0;0;False;0;False;1000;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.DistanceOpNode;59;-1876.969,447.4693;Inherit;False;2;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;118;-1851.125,557.7252;Inherit;False;Property;_DistanceFadeStart;Distance Fade Start;8;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;144;-579.577,-1628.581;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;19;-547.1661,-1369.41;Inherit;False;HeightFadeStart;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;24;-835.1268,-1131.109;Inherit;False;Property;_DistanceMult;DistanceMult;3;0;Create;True;0;0;0;False;0;False;1;1;0;1000;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;25;-1841.369,738.7874;Inherit;False;22;WorldPos;1;0;OBJECT;;False;1;FLOAT4;0
Node;AmplifyShaderEditor.TFHCRemapNode;64;-1553.688,405.0609;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1000;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;30;-1657.99,988.389;Inherit;False;19;HeightFadeStart;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode;31;-1601.135,740.4243;Inherit;False;FLOAT4;1;0;FLOAT4;0,0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.RangedFloatNode;35;-1565.727,606.6324;Inherit;False;Property;_FalloffExponent;Falloff Exponent;5;0;Create;True;0;0;0;False;0;False;1;0;0;10;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;28;-422.6223,-1620.32;Inherit;False;HeightFadeLength;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;32;-557.1276,-1138.109;Inherit;False;Distance;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;36;-1180.938,404.4488;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;33;-1383.755,993.5777;Inherit;False;28;HeightFadeLength;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;27;-1178.991,648.5416;Inherit;False;32;Distance;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;34;-1320.268,772.5607;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;7;-960.9885,404.0943;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;8;-1056.626,918.5459;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.001;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;74;-1122.87,162.1206;Inherit;False;Property;_Levels;Levels;6;0;Create;True;0;0;0;False;0;False;1;1;1;256;0;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;11;-808.3849,442.1427;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;17;-825.5459,895.2499;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RoundOpNode;95;-847.2252,181.356;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;13;-656.2161,506.5936;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;76;-549.0114,101.9981;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FloorOpNode;84;-423.4398,101.8099;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;77;-269.0113,107.998;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;29;-757.515,-495.566;Inherit;False;Property;_FogFarColor;Fog Far Color;1;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RegisterLocalVarNode;18;-524.2018,-497.6302;Inherit;False;FarCol;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;114;-178.2045,442.1931;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;26;-768.868,-679.5711;Inherit;False;Property;_FogNearColor;Fog Near Color;0;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.AbsOpNode;115;-43.20447,454.1931;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;6;-2135.419,-89.89456;Inherit;False;18;FarCol;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;86;-549.7987,275.7136;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;9;-520.2018,-704.6302;Inherit;False;NearCol;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.TemplateShaderPropertyNode;1;-2714.939,-493.6325;Inherit;False;0;0;_MainTex;Shader;False;0;5;SAMPLER2D;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.FogAndAmbientColorsNode;119;-2175.834,71.60073;Inherit;False;unity_FogColor;0;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;5;-1907.132,-628.8477;Inherit;False;9;NearCol;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.CeilOpNode;85;-411.596,280.6762;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;116;69.79547,422.1931;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;73;-2561.927,-443.6802;Inherit;False;Screen;-1;True;1;0;SAMPLER2D;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.ToggleSwitchNode;126;-1896.139,-23.72925;Inherit;False;Property;_SyncUnityDefaultFogColor;Sync Unity Default Fog Color;9;0;Create;True;0;0;0;False;0;False;1;True;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SamplerNode;2;-2336.243,-429.1864;Inherit;True;Property;_TextureSample0;Texture Sample 0;0;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleDivideOpNode;87;-269.645,263.2726;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode;16;-1643.507,-391.5241;Inherit;False;COLOR;1;0;COLOR;0,0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.BreakToComponentsNode;10;-1612.703,69.98404;Inherit;False;COLOR;1;0;COLOR;0,0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.DitheringNode;113;190.7955,437.1931;Inherit;False;1;False;4;0;FLOAT;0;False;1;SAMPLER2D;;False;2;FLOAT4;0,0,0,0;False;3;SAMPLERSTATE;;False;1;FLOAT;0
Node;AmplifyShaderEditor.Compare;101;350.042,277.7875;Inherit;False;0;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;12;-1458.12,-173.4324;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.LerpOp;14;-1438.239,-576.9821;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.LerpOp;15;553.5351,44.00872;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;906.5743,-73.68818;Float;False;True;-1;2;ASEMaterialInspector;0;5;Screen Space Fog;c71b220b631b6344493ea3cf87110c93;True;SubShader 0 Pass 0;0;0;SubShader 0 Pass 0;1;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;True;7;False;;False;True;0;False;False;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;0;;0;0;Standard;0;0;1;True;False;;False;0
WireConnection;22;0;3;0
WireConnection;140;0;141;0
WireConnection;142;0;139;0
WireConnection;142;1;140;0
WireConnection;133;0;131;0
WireConnection;143;0;142;0
WireConnection;143;1;133;0
WireConnection;127;0;143;0
WireConnection;127;1;130;0
WireConnection;135;0;127;0
WireConnection;135;1;136;0
WireConnection;146;0;135;0
WireConnection;23;1;20;0
WireConnection;145;0;21;0
WireConnection;145;1;146;0
WireConnection;138;0;23;0
WireConnection;138;1;135;0
WireConnection;59;0;38;0
WireConnection;59;1;60;0
WireConnection;144;0;138;0
WireConnection;19;0;145;0
WireConnection;64;0;59;0
WireConnection;64;1;118;0
WireConnection;64;2;117;0
WireConnection;31;0;25;0
WireConnection;28;0;144;0
WireConnection;32;0;24;0
WireConnection;36;0;64;0
WireConnection;36;1;35;0
WireConnection;34;0;31;1
WireConnection;34;1;30;0
WireConnection;7;0;36;0
WireConnection;7;1;27;0
WireConnection;8;0;34;0
WireConnection;8;1;33;0
WireConnection;11;0;7;0
WireConnection;17;0;8;0
WireConnection;95;0;74;0
WireConnection;13;0;11;0
WireConnection;13;2;17;0
WireConnection;76;0;95;0
WireConnection;76;1;13;0
WireConnection;84;0;76;0
WireConnection;77;0;84;0
WireConnection;77;1;95;0
WireConnection;18;0;29;0
WireConnection;114;0;77;0
WireConnection;114;1;13;0
WireConnection;115;0;114;0
WireConnection;86;0;95;0
WireConnection;86;1;13;0
WireConnection;9;0;26;0
WireConnection;85;0;86;0
WireConnection;116;0;95;0
WireConnection;116;1;115;0
WireConnection;73;0;1;0
WireConnection;126;0;6;0
WireConnection;126;1;119;0
WireConnection;2;0;73;0
WireConnection;87;0;85;0
WireConnection;87;1;95;0
WireConnection;16;0;5;0
WireConnection;10;0;126;0
WireConnection;113;0;116;0
WireConnection;101;0;113;0
WireConnection;101;2;77;0
WireConnection;101;3;87;0
WireConnection;12;0;2;0
WireConnection;12;1;126;0
WireConnection;12;2;10;3
WireConnection;14;0;2;0
WireConnection;14;1;5;0
WireConnection;14;2;16;3
WireConnection;15;0;14;0
WireConnection;15;1;12;0
WireConnection;15;2;101;0
WireConnection;0;0;15;0
ASEEND*/
//CHKSM=B0836E6751678D54EAEA1B864561973491398076