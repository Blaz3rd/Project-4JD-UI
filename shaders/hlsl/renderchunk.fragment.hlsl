#include "ShaderConstants.fxh"
#include "util.fxh"

struct PS_Input
{
	float4 position : SV_Position;

#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 color : COLOR;
	snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
	snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif

#ifdef NEAR_WATER
	float cameraDist : TEXCOORD_2;
#endif

#ifdef FOG
	float4 fogColor : FOG_COLOR;
#endif
};

struct PS_Output
{
	float4 color : SV_Target;
};

/////////////////////////////////////////////////////////////////////////////
//	Shader Settings
/////////////////////////////////////////////////////////////////////////////

#define saturation 1.0
#define exposure 1.0
#define brightness 1.0
#define gamma 2.0
#define contrast 1.0

/////////////////////////////////////////////////////////////////////////////
//	Filmic curve
/////////////////////////////////////////////////////////////////////////////

float filmic_curve(float x) {

// Shoulder strength
float A = 0.22;
// Linear strength
float B = 0.5;
// Linear angle
float C = 0.15 * brightness;
// Toe strength
float D = 0.4 * gamma;
// Toe numerator
float E = 0.01 * contrast;
// Toe denominator
float F = 0.2;

return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;

}

/////////////////////////////////////////////////////////////////////////////
//	Tone Mapping
/////////////////////////////////////////////////////////////////////////////

float3 tone_mapping(float3 clr) {

float W = 1.0 / exposure;

float Luma = dot(clr, float3(0.0, 0.3, 0.3));
float3 Chroma = clr - Luma;
clr = (Chroma * saturation) + Luma;
clr = float3(filmic_curve(clr.r), filmic_curve(clr.g), filmic_curve(clr.b)) / filmic_curve(W);

return clr;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////


void main( in PS_Input PSInput, out PS_Output PSOutput )
{
#ifdef BYPASS_PIXEL_SHADER
    PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    return;
#else

#if USE_TEXEL_AA
	float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv0 );
#else
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv0);
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0f;
	PSInput.color.b = 1.0f;
#endif

#if USE_ALPHA_TEST
	#ifdef ALPHA_TO_COVERAGE
	#define ALPHA_THRESHOLD 0.05
	#else
	#define ALPHA_THRESHOLD 0.5
	#endif
	if(diffuse.a < ALPHA_THRESHOLD)
		discard;
#endif

#if !defined(ALWAYS_LIT)
	diffuse = diffuse * TEXTURE_1.Sample(TextureSampler1, PSInput.uv1);
#endif

#ifndef SEASONS

#if !USE_ALPHA_TEST && !defined(BLEND)
	diffuse.a = PSInput.color.a;
#elif defined(BLEND)
#ifdef NEAR_WATER	
	diffuse.a *= PSInput.color.a;
	float alphaFadeOut = saturate(PSInput.cameraDist.x);
	diffuse.a = lerp(diffuse.a, 1.0f, alphaFadeOut);
#endif

#endif	
	diffuse.rgb *= PSInput.color.rgb;
#else
	float2 uv = PSInput.color.xy;
	diffuse.rgb *= lerp(1.0f, TEXTURE_2.Sample(TextureSampler2, uv).rgb*2.0f, PSInput.color.b);
	diffuse.rgb *= PSInput.color.aaa;
	diffuse.a = 1.0f;
#endif

/////////////////////////////////////////////////////////////////////////////
//	Tone Mapping
/////////////////////////////////////////////////////////////////////////////

#ifdef ALPHA_TEST
diffuse.rgb = lerp(diffuse.rgb, 0.75f * diffuse.rgb, min(max(0.9 - PSInput.color.r, 0.0 ), 1.0 ));
#else
diffuse.rgb = lerp(diffuse.rgb, 0.5f * diffuse.rgb, min(max(0.9 - PSInput.color.r, 0.0 ), 1.0 ));
#endif

diffuse.rgb = tone_mapping(diffuse.rgb);

/////////////////////////////////////////////////////////////////////////////

#ifdef FOG
	diffuse.rgb = lerp( diffuse.rgb, PSInput.fogColor.rgb, PSInput.fogColor.a );
#endif

	PSOutput.color = diffuse;

#ifdef VR_MODE
	// On Rift, the transition from 0 brightness to the lowest 8 bit value is abrupt, so clamp to 
	// the lowest 8 bit value.
	PSOutput.color = max(PSOutput.color, 1 / 255.0f);
#endif

#endif // BYPASS_PIXEL_SHADER
}