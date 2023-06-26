#if !defined COMPOSITE_GLSL_INCLUDED
#define COMPOSITE_GLSL_INCLUDED

#if defined COMPOSITE_FSH
#	extension GL_ARB_explicit_attrib_location : enable
	const bool colortex0MipmapEnabled = true;

	uniform sampler2D colortex0, colortex3;

	in vec2 uv;

	/* DRAWBUFFERS:0 */
	layout(location = 0) out vec4 fragData0;

	#include "/utils/reflective_vanilla_config.glsl"

	void main() {
	vec3 albedo = texture(colortex0, uv).rgb;
	vec4 translucent = texture(colortex3, uv);
	
	albedo = textureLod(colortex0, uv, TRANSLUCENT_BLUR_INTENSITY * translucent.a).rgb * (1.0 - translucent.a) + translucent.rgb;

		/* colortex0 (gcolor) */
		fragData0 = vec4(albedo, 1.0);
	}
#endif /* defined COMPOSITE_FSH */

#if defined COMPOSITE_VSH
	uniform mat4 modelViewMatrix;
	uniform mat4 projectionMatrix;

	in vec2 vaUV0;
	in vec3 vaPosition;

	out vec2 uv;

	void main() {
	uv = vaUV0;
		gl_Position = projectionMatrix * (modelViewMatrix * vec4(vaPosition, 1.0));
	}
#endif /* defined COMPOSITE_VSH */

#endif /* !defined COMPOSITE_GLSL_INCLUDED */