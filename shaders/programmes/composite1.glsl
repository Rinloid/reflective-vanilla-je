#if !defined COMPOSITE1_GLSL_INCLUDED
#define COMPOSITE1_GLSL_INCLUDED

#if defined COMPOSITE1_FSH
#	extension GL_ARB_explicit_attrib_location : enable

	uniform sampler2D colortex0, colortex2, colortex4, colortex6;
	uniform sampler2D depthtex0, depthtex1;
	uniform mat4 gbufferProjection, gbufferProjectionInverse;
	uniform mat4 gbufferModelView, gbufferModelViewInverse;
	uniform vec3 skyColor, fogColor;

	in vec2 uv;

	/* DRAWBUFFERS:036 */
	layout(location = 0) out vec4 fragData0;
	layout(location = 1) out vec4 fragData1;
	layout(location = 2) out vec4 fragData2;

	vec4 getViewPos(const mat4 projInv, const vec2 uv, const float depth) {
		vec4 viewPos = projInv * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);

		return viewPos / viewPos.w;
	}

	vec3 getScreenPos(const mat4 proj, const vec3 pos) {
		vec4 viewPos = proj * vec4(pos, 1.0);

		return (viewPos.xyz / viewPos.w) * 0.5 + 0.5;
	}

	vec4 getRelPos(const mat4 modelViewInv, const mat4 projInv, const vec2 uv, const float depth) {
		vec4 relPos = modelViewInv * getViewPos(projInv, uv, depth);
		
		return relPos / relPos.w;
	}

	#include "/utils/reflective_vanilla_config.glsl"

	/*
	 ** Based on one by sad (@bamb0san)
	 ** https://github.com/bambosan/Water-Only-Shaders
	*/
	vec3 getRayTracePosHit(sampler2D depthTex, const mat4 proj, const vec3 viewPos, const vec3 refPos) {
		const int raySteps = SSR_RAYTRACING_STEPS;

		vec3 result = vec3(0.0);

		vec3 rayOrig = getScreenPos(proj, viewPos);
		vec3 rayDir  = getScreenPos(proj, viewPos + refPos);
		rayDir = normalize(rayDir - rayOrig) / float(raySteps);

		float prevDepth = texture(depthTex, rayOrig.xy).r;
		for (int i = 0; i < raySteps && refPos.z < 0.0 && rayOrig.x > 0.0 && rayOrig.y > 0.0 && rayOrig.x < 1.0 && rayOrig.y < 1.0; i++) {
			float currDepth = texture(depthTex, rayOrig.xy).r;
			if (rayOrig.z > currDepth && prevDepth < currDepth) {
				result = vec3(rayOrig.xy, 1.0);
				break;
			}
			
			rayOrig += rayDir;
		}
		
		return result;
	}

	void main() {
	vec3 albedo = texture(colortex0, uv).rgb;
	vec3 normal = texture(colortex2, uv).rgb * 2.0 - 1.0;

	float outdoor = texture(colortex4, uv).r;
	float roughness = texture(colortex4, uv).b;
	float F0 = texture(colortex4, uv).g;

	float depth0 = texture(depthtex0, uv).r;
	float depth1 = texture(depthtex1, uv).r;
	
	vec3 viewPos = getViewPos(gbufferProjectionInverse, uv, depth0).xyz;
	vec3 relPos = getRelPos(gbufferModelViewInverse, gbufferProjectionInverse, uv, depth0).xyz;
	vec3 skyPos = reflect(normalize(relPos), normal);

	vec3 skyReflection = vec3(1.0);
	#ifdef ENABLE_SKY_REFLECTION
		skyReflection = mix(skyColor, fogColor, smoothstep(0.75, 0.9, 1.0 - skyPos.y));
	#endif

	vec3 reflection = mix(vec3(1.0), skyReflection, outdoor);
	vec3 sunMoonReflection = vec3(0.0);

	vec3 refPos = reflect(normalize(viewPos), mat3(gbufferModelView) * normal);
	vec3 refUV = getScreenPos(gbufferProjection, refPos);

	#ifdef ENABLE_SSR
		#ifdef SSR_RAYTRACING
			if (getRayTracePosHit(depthtex0, gbufferProjection, viewPos, refPos).z > 0.5) {
				reflection = texture(colortex0, getRayTracePosHit(depthtex0, gbufferProjection, viewPos, refPos).xy).rgb;
			}
		#else
			if (!(refUV.x < 0 || refUV.x > 1 || refUV.y < 0 || refUV.y > 1 || refUV.z < 0 || refUV.z > 1.0)) {
				reflection = texture(colortex0, refUV.xy).rgb;
			}
		#endif
	#endif

	if (!(refUV.x < 0 || refUV.x > 1 || refUV.y < 0 || refUV.y > 1 || refUV.z < 0 || refUV.z > 1.0)) {
		sunMoonReflection = texture(colortex6, refUV.xy).rgb;
	}

		/* colortex0 (gcolor) */
		fragData0 = vec4(albedo, 1.0);

		/* colortex3 (composite) */
		fragData1 = vec4(reflection, 1.0);

		/* colortex6 (gaux3) */
		fragData2 = vec4(sunMoonReflection, 1.0);
	}
#endif /* defined COMPOSITE1_FSH */

#if defined COMPOSITE1_VSH
	uniform mat4 modelViewMatrix;
	uniform mat4 projectionMatrix;

	in vec2 vaUV0;
	in vec3 vaPosition;

	out vec2 uv;

	void main() {
	uv = vaUV0;
		gl_Position = projectionMatrix * (modelViewMatrix * vec4(vaPosition, 1.0));
	}
#endif /* defined COMPOSITE1_VSH */

#endif /* !defined COMPOSITE1_GLSL_INCLUDED */