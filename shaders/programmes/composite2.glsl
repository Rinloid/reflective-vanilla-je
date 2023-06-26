#if !defined COMPOSITE2_GLSL_INCLUDED
#define COMPOSITE2_GLSL_INCLUDED

#if defined COMPOSITE2_FSH
#	extension GL_ARB_explicit_attrib_location : enable
	const bool colortex3MipmapEnabled = true;

	uniform sampler2D colortex0, colortex2, colortex3, colortex4, colortex5, colortex6;
	uniform sampler2D depthtex0, depthtex1;
	uniform mat4 gbufferProjection, gbufferProjectionInverse;
	uniform mat4 gbufferModelView, gbufferModelViewInverse;
	uniform vec3 fogColor;
	uniform float rainStrength;

	in vec2 uv;
	in vec3 sunPos;
	in vec3 moonPos;
	in vec3 shadowLightPos;

	/* DRAWBUFFERS:0 */
	layout(location = 0) out vec4 fragData0;

	vec4 getViewPos(const mat4 projInv, const vec2 uv, const float depth) {
		vec4 viewPos = projInv * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);

		return viewPos / viewPos.w;
	}

	vec4 getRelPos(const mat4 modelViewInv, const mat4 projInv, const vec2 uv, const float depth) {
		vec4 relPos = modelViewInv * getViewPos(projInv, uv, depth);
		
		return relPos / relPos.w;
	}

	vec3 fresnelSchlick(const vec3 H, const vec3 N, const vec3 reflectance) {
		float cosTheta = clamp(1.0 - max(0.0, dot(H, N)), 0.0, 1.0);

		return reflectance + (1.0 - reflectance) * cosTheta * cosTheta * cosTheta * cosTheta * cosTheta;
	}

	vec3 getPBRSpecular(const vec3 V, const vec3 L, const vec3 N, const float R, const vec3 reflectance) {
		vec3  H = normalize(V + L);
		float D = (R * R)
				/ (3.14159265359 * (max(0.0, dot(H, N)) * max(0.0, dot(H, N)) * (R * R - 1.0) + 1.0) * (max(0.0, dot(H, N)) * max(0.0, dot(H, N)) * (R * R - 1.0) + 1.0));
		float G = ((max(0.0, dot(V, N))) / (max(0.0, dot(V, N)) + ((R + 1.0) * (R + 1.0)) * 0.125))
				* ((max(0.0, dot(L, N))) / (max(0.0, dot(L, N)) + ((R + 1.0) * (R + 1.0)) * 0.125));
		vec3  F = fresnelSchlick(H, V, reflectance);

		return vec3(clamp((D * G * F) / max(0.001, 4.0 * max(dot(N, V), 0.0) * max(dot(L, N), 0.0)), 0.0, 1.0));
	}

	// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
	vec3 getEnvironmentBRDF(const vec3 H, const vec3 N, const float R, const vec3 reflectance) {
		vec4 r = R * vec4(-1.0, -0.0275, -0.572,  0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
		vec2 AB = vec2(-1.04, 1.04) * min(r.x * r.x, exp2(-9.28 * max(0.0, dot(H, N)))) * r.x + r.y + r.zw;

		return reflectance * AB.x + AB.y;
	}

	vec3 brighten(const vec3 col) {
		float rgbMax = max(col.r, max(col.g, col.b));
		float delta  = 1.0 - rgbMax;

		return col + delta;
	}

	/* 
	** Uncharted 2 tone mapping
	** See: http://filmicworlds.com/blog/filmic-tonemapping-operators/
	*/
	vec3 uncharted2ToneMapFilter(const vec3 col) {
		const float A = 0.15; // Shoulder strength
		const float B = 0.50; // Linear strength
		const float C = 0.10; // Linear angle
		const float D = 0.10; // Toe strength
		const float E = 0.02; // Toe numerator
		const float F = 0.30; // Toe denominator

		return ((col * (A * col + C * B) + D * E) / (col * (A * col + B) + D * F)) - E / F;
	}
	vec3 uncharted2ToneMap(const vec3 col) {
		const float W = 3.0;

		vec3 curr = uncharted2ToneMapFilter(col * 2.0);
		vec3 whiteScale = 1.0 / uncharted2ToneMapFilter(vec3(W));
		vec3 color = curr * whiteScale;

		return color;
	}

	vec3 contrastFilter(const vec3 col, const float contrast) {
		return (col - 0.5) * max(contrast, 0.0) + 0.5;
	}

	#include "/utils/reflective_vanilla_config.glsl"

	void main() {
	vec3 albedo = texture(colortex0, uv).rgb;
	vec3 normal = texture(colortex2, uv).rgb * 2.0 - 1.0;
	vec4 fog = texture(colortex5, uv);
	vec3 sunMoon = texture(colortex6, uv).rgb;

	float depth0 = texture(depthtex0, uv).r;
	float depth1 = texture(depthtex1, uv).r;

	vec4 viewPos = getViewPos(gbufferProjectionInverse, uv, depth0);
	vec3 relPos = getRelPos(gbufferModelViewInverse, gbufferProjectionInverse, uv, depth0).xyz;

	vec3 viewDir = -normalize(relPos);

	float outdoor = texture(colortex4, uv).r;
	float roughness = texture(colortex4, uv).b;
	float F0 = texture(colortex4, uv).g;
	vec3 reflectance = mix(vec3(0.04, 0.04, 0.04), albedo.rgb, F0);
	vec3 fresnel = fresnelSchlick(viewDir, normal, reflectance);

	if (depth0 != 1.0 && outdoor != 0.0) {
		vec3 reflection = textureLod(colortex3, uv, SSR_BLUR_INTENSITY + roughness * SSR_ROUGHNESS_BLUR_INTENSITY).rgb * getEnvironmentBRDF(viewDir, normal, roughness, reflectance);
		albedo = albedo * (1.0 - F0) + reflection * fresnel;
		
		#ifdef ENABLE_GAMMA_CORRECTION
			albedo = pow(albedo, vec3(2.2));
		#endif
		
		vec3 lightCol = brighten(fogColor) * SUNLIGHT_INTENSITY * (1.0 - rainStrength) * smoothstep(0.8, 1.0, outdoor) * smoothstep(0.0, 0.1, sin(sunPos.y));
		
		vec3 sunLightReflection = lightCol *
		#if SUNLIGHT_TYPE == 0 // Specular
			getPBRSpecular(viewDir, shadowLightPos, normal, roughness, reflectance);
		#elif SUNLIGHT_TYPE == 1 // Vanilla
			sunMoon;
		#endif


		albedo = albedo + sunLightReflection * fresnel;

		#ifdef ENABLE_TONEMAPPING
			albedo = uncharted2ToneMap(albedo);
		#endif

		#ifdef ENABLE_GAMMA_CORRECTION
			albedo = pow(albedo, vec3(1.0 / 2.2));
		#endif

		albedo = contrastFilter(albedo, CONTRAST_FILTER_INTENSITY);
		albedo = mix(albedo, fog.rgb, fog.a);
	}

		/* colortex0 (gcolor) */
		fragData0 = vec4(albedo.rgb, 1.0);
	}
#endif /* defined COMPOSITE2_FSH */

#if defined COMPOSITE2_VSH
	uniform mat4 modelViewMatrix;
	uniform mat4 projectionMatrix;
	uniform mat4 gbufferModelView, gbufferModelViewInverse;
	uniform vec3 sunPosition, moonPosition, shadowLightPosition;

	in vec2 vaUV0;
	in vec3 vaPosition;

	out vec2 uv;
	out vec3 sunPos;
	out vec3 moonPos;
	out vec3 shadowLightPos;

	void main() {
	uv = vaUV0;
	sunPos         = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	moonPos        = normalize(mat3(gbufferModelViewInverse) * moonPosition);
	shadowLightPos = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
		gl_Position = projectionMatrix * (modelViewMatrix * vec4(vaPosition, 1.0));
	}
#endif /* defined COMPOSITE2_VSH */

#endif /* !defined COMPOSITE2_GLSL_INCLUDED */