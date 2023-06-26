#if !defined GBUFFERS_GLSL_INCLUDED
#define GBUFFERS_GLSL_INCLUDED 1

#if defined GBUFFERS_WATER || defined GBUFFERS_HAND_WATER
#	define GBUFFERS_TRANSLUCENT 1
#endif

#if defined GBUFFERS_CLOUDS || defined GBUFFERS_SKYBASIC || defined GBUFFERS_SKYTEXTURED
#	define GBUFFERS_SKY 1
#endif

#if defined GBUFFERS_ARMOR_GLINT || defined GBUFFERS_BEACONBEAM || defined GBUFFERS_BLOCK || defined GBUFFERS_CLOUDS || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND_WATER || defined GBUFFERS_HAND || defined GBUFFERS_SKYTEXTURED || defined GBUFFERS_SPIDEREYES || defined GBUFFERS_TERRAIN || defined GBUFFERS_TEXTURED_LIT || defined GBUFFERS_TEXTURED || defined GBUFFERS_WATER || defined GBUFFERS_WEATHER
#	define USE_TEXTURES 1
#endif

#if defined GBUFFERS_BASIC || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || GBUFFERS_HAND_WATER || defined GBUFFERS_HAND || defined GBUFFERS_TERRAIN || defined GBUFFERS_TEXTURED_LIT || defined GBUFFERS_TEXTURED || defined GBUFFERS_WATER || defined GBUFFERS_WEATHER
#   define USE_LIGHTMAP 1
#endif

#if defined GBUFFERS_TERRAIN || defined GBUFFERS_WATER
#	define USE_CHUNK_OFFSET 1
#endif

#if defined GBUFFERS_BASIC || defined GBUFFERS_BEACONBEAM || defined GBUFFERS_BLOCK || defined GBUFFERS_CLOUDS || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND_WATER || defined GBUFFERS_HAND || defined GBUFFERS_LINE || defined GBUFFERS_SPIDEREYES || defined GBUFFERS_TERRAIN || defined GBUFFERS_TEXTURED_LIT || defined GBUFFERS_TEXTURED || defined GBUFFERS_WATER || defined GBUFFERS_WEATHER
#	define USE_ALPHA_TEST 1
#endif

#if defined GBUFFERS_FSH
#	extension GL_ARB_explicit_attrib_location : enable

#	if defined USE_TEXTURES
		uniform sampler2D gtexture;
		uniform sampler2D normals;
		uniform sampler2D specular;
		uniform ivec2 atlasSize;
#	endif
#	if defined USE_LIGHTMAP
		uniform sampler2D lightmap;
#	endif
#	if defined GBUFFERS_BASIC
		uniform int renderStage;
#	endif
#	if defined USE_ALPHA_TEST
		uniform float alphaTestRef;
#	endif
#	if defined GBUFFERS_ENTITIES
		uniform vec4 entityColor;
#	endif
	uniform sampler2D depthtex0, depthtex1;
	uniform mat4 gbufferProjection, gbufferProjectionInverse;
	uniform mat4 gbufferModelView, gbufferModelViewInverse;
	uniform vec3 cameraPosition;
	uniform vec3 fogColor;
	uniform float fogStart, fogEnd;
	uniform float viewHeight, viewWidth;
	uniform int fogMode;

#	if defined USE_TEXTURES
		in vec2 uv0;
#	endif
#	if defined USE_LIGHTMAP
		in vec2 uv1;
#	endif
	in float mcEntity;
	in vec4 col;
	in vec4 viewPos;
	in vec4 relPos;
	in vec3 vNormal;
	in vec3 sunPos;
	in vec3 moonPos;
	in vec3 shadowLightPos;
	in mat3 tbnMatrix;

	/* DRAWBUFFERS:0123456 */
	layout(location = 0) out vec4 fragData0;
	layout(location = 1) out vec4 fragData1;
	layout(location = 2) out vec4 fragData2;
	layout(location = 3) out vec4 fragData3;
	layout(location = 4) out vec4 fragData4;
	layout(location = 5) out vec4 fragData5;
	layout(location = 6) out vec4 fragData6;

	float fresnelSchlick(const vec3 H, const vec3 N, const float reflectance) {
		float cosTheta = clamp(1.0 - max(0.0, dot(H, N)), 0.0, 1.0);

		return reflectance + (1.0 - reflectance) * cosTheta * cosTheta * cosTheta * cosTheta * cosTheta;
	}

	float getFog(const int fogMode, const float fogStart, const float fogEnd, const vec4 pos) {
		if (fogMode == 9729) { // GL_LINEAR
			return clamp((length(pos) - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
		} else if (fogMode == 2048) { // GL_EXP
			return 1.0 - clamp(1.0 / exp(max(0.0, length(pos) - fogStart) * log(1.0 / 0.03) / (fogEnd - fogStart)), 0.0, 1.0);
		} else if (fogMode == 2049) { // GL_EXP2
			float base = max(0.0, length(pos) - fogStart) * sqrt(log(1.0 / 0.015)) / (fogEnd - fogStart);
			return 1.0 - clamp(1.0 / exp(base * base), 0.0, 1.0);
		} else {
			return 0.0;
		}
	}

	#include "/utils/reflective_vanilla_config.glsl"

	void main() {
	float vanillaAO = 0.0;
	vec4 albedo = col;
#	if defined USE_TEXTURES
		albedo *= texture(gtexture, uv0);
#	endif
	vec4 translucent = vec4(0.0);
	vec4 sunMoon = vec4(0.0);
#	if defined USE_ALPHA_TEST
		if (albedo.a < alphaTestRef) discard;
#	endif
#	if defined USE_LIGHTMAP
#		if defined GBUFFERS_BASIC
			/*
			 ** Leads have light levels, but chunk borders don't.
			 * And for whatever reason, chunk borders use gbuffers_basic
			 * instead of gbuffers_line, so we detect them with renderStage.
			*/
			if (renderStage != MC_RENDER_STAGE_DEBUG) {
				albedo *= texture(lightmap, uv1);
			}
#		else
			albedo *= texture(lightmap, uv1);
#		endif
#	endif
#	if defined GBUFFERS_ENTITIES
		albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#	endif
	vec3 fragPos = viewPos.xyz + cameraPosition;

#		if !defined GBUFFERS_SKY
#			if defined USE_TEXTURES && defined MC_NORMAL_MAP
				vec3 fNormal = normalize(vec3(texture(normals, uv0).rg * 2.0 - 1.0, sqrt(1.0 - dot(texture(normals, uv0).rg * 2.0 - 1.0, texture(normals, uv0).rg * 2.0 - 1.0))));
				fNormal = fNormal * tbnMatrix;
#			else
				vec3 fNormal = vNormal;
#			endif
#		else
			vec3 fNormal = normalize(cross(dFdx(fragPos), dFdy(fragPos)));
#		endif
		fNormal = mat3(gbufferModelViewInverse) * fNormal;

	float perceptualSmoothness = 0.0;
	float F0 = 0.0;

#	if defined USE_TEXTURES && defined MC_SPECULAR_MAP
		perceptualSmoothness = texture(specular, uv0).r;
		F0 = texture(specular, uv0).g;
#	endif

#	if defined USE_TEXTURES
		if (int(mcEntity) == 1) {
			perceptualSmoothness = WATER_SMOOTHNESS;
			albedo.a = WATER_TRANSPARENCY;
			F0 = WATER_REFLECTANCE;
		}
#	endif

	float roughness = (1.0 - perceptualSmoothness) * (1.0 - perceptualSmoothness);

#	if defined GBUFFERS_TRANSLUCENT
		albedo.a = mix(albedo.a, 1.0, fresnelSchlick(-normalize(relPos.xyz), fNormal, mix(0.04, dot(albedo.rgb, vec3(0.22, 0.707, 0.071)), F0)));
		translucent = albedo;
		albedo.a = 0.0;
#	endif

	vec4 fog = vec4(fogColor, getFog(fogMode, fogStart, fogEnd, viewPos));
#	if !defined GBUFFERS_SKYTEXTURED
		albedo.rgb = mix(albedo.rgb, fog.rgb, fog.a);
#	else
		sunMoon = albedo;
#	endif
	fog.a *= F0;

		/* colortex0 (gcolor) */
		fragData0 = albedo;

		/* colortex1 (gdepth, unused) */
		fragData1 = vec4(0.0);

		/* colortex2 (gnormal) */
		fragData2 = vec4((fNormal + 1.0) * 0.5, 1.0);

		/* colortex3 (composite) */
		fragData3 = translucent;

		/* colortex4 (gaux1) */
#		if defined USE_LIGHTMAP
#			if defined USE_TEXTURES
				fragData4 = vec4(uv1.y, F0, roughness, 1.0);
#			else
				fragData4 = vec4(uv1.y, vec2(0.0), 1.0);
#			endif
#		else
#			if defined USE_TEXTURES
				fragData4 = vec4(0.0, F0, roughness, 1.0);
#			else
				fragData4 = vec4(0.0, vec2(0.0), 1.0);
#			endif
#		endif

		/* colortex5 (gaux2) */
		fragData5 = fog;

		/* colortex6 (gaux3) */
		fragData6 = sunMoon;
	}
#endif /* defined GBUFFERS_FSH */

#if defined GBUFFERS_VSH
#	if defined GBUFFERS_LINE
		const float LINE_WIDTH  = 2.0;
		const float VIEW_SHRINK = 0.9609375 /* 1.0 - (1.0 / 256.0) */ ;
		const mat4 VIEW_SCALE   = mat4(
			VIEW_SHRINK, 0.0, 0.0, 0.0,
			0.0, VIEW_SHRINK, 0.0, 0.0,
			0.0, 0.0, VIEW_SHRINK, 0.0,
			0.0, 0.0, 0.0, 1.0
		);
		
		uniform float viewHeight, viewWidth;
#	endif

	uniform mat4 modelViewMatrix;
	uniform mat4 projectionMatrix;
	uniform mat4 gbufferModelView, gbufferModelViewInverse;
	uniform mat3 normalMatrix;
	uniform vec3 sunPosition, moonPosition, shadowLightPosition;
#	if defined USE_TEXTURES
		// Set a default value when the uniform is not bound.
		uniform mat4 textureMatrix = mat4(1.0);
#	endif
#	if defined USE_CHUNK_OFFSET
		uniform vec3 chunkOffset;
#	endif

#	if defined USE_TEXTURES
		in vec2 vaUV0;
#	endif
#	if defined USE_LIGHTMAP
		in ivec2 vaUV2;
#	endif
	in vec3 vaNormal;
	in vec3 vaPosition;
	in vec4 vaColor;
	in vec3 mc_Entity;
	in vec4 at_tangent;

#	if defined USE_TEXTURES
		out vec2 uv0;
#	endif
#	if defined USE_LIGHTMAP
		out vec2 uv1;
#	endif
	out float mcEntity;
	out vec4 col;
	out vec4 viewPos;
	out vec4 relPos;
	out vec3 vNormal;
	out vec3 sunPos;
	out vec3 moonPos;
	out vec3 shadowLightPos;
	out mat3 tbnMatrix;

	void main() {
#	if defined USE_TEXTURES
		uv0 = (textureMatrix * vec4(vaUV0, 0.0, 1.0)).xy;
#	endif
#	if defined USE_LIGHTMAP
		uv1 = vaUV2 * 0.00390625 /* (1.0 / 256.0) */ + 0.03125 /* (1.0 / 32.0) */ ;
#	endif
	mcEntity = 0.1;
	
	if (int(mc_Entity.x) == 10001) mcEntity = 1.1; // Water
	col = vaColor;

	vec4 worldPos = vec4(vaPosition, 1.0);
#	if defined USE_CHUNK_OFFSET
		worldPos.xyz += chunkOffset;
#	endif

	viewPos = modelViewMatrix * worldPos;
	relPos = worldPos;

	vec3 tangent  = normalize(normalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(normalMatrix * cross(at_tangent.xyz, vaNormal) * at_tangent.w);
	
	vNormal    = normalize(normalMatrix * vaNormal);
	tbnMatrix  = transpose(mat3(tangent, binormal, vNormal));

#	if defined GBUFFERS_LINE
		vNormal = vec3(0.0);
#	endif

	sunPos         = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	moonPos        = normalize(mat3(gbufferModelViewInverse) * moonPosition);
	shadowLightPos = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

#		if defined GBUFFERS_LINE
		vec2 resolution   = vec2(viewWidth, viewHeight);
		vec4 linePosStart = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vec4(vaPosition, 1.0)));
		vec4 linePosEnd   = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vec4(vaPosition + vaNormal, 1.0)));

		vec3 ndc1 = linePosStart.xyz / linePosStart.w;
		vec3 ndc2 = linePosEnd.xyz   / linePosEnd.w;

		vec2 lineScreenDirection = normalize((ndc2.xy - ndc1.xy) * resolution);
		vec2 lineOffset = vec2(-lineScreenDirection.y, lineScreenDirection.x) * LINE_WIDTH / resolution;

		if (lineOffset.x < 0.0) lineOffset = -lineOffset;
		if (gl_VertexID % 2 != 0) lineOffset = -lineOffset;
			
			gl_Position = vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
#		else
			gl_Position = projectionMatrix * (modelViewMatrix * worldPos);
#		endif
	}
#endif /* defined GBUFFERS_VSH */

#endif /* !defined GBUFFERS_GLSL_INCLUDED */