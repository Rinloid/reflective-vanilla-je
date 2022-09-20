#version 120

uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D depthtex0;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;

varying vec2 uv;

vec4 getViewPos(const mat4 projInv, const vec2 uv, const float depth) {
	vec4 viewPos = projInv * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);

	return viewPos / viewPos.w;
}

vec4 getRelPos(const mat4 modelViewInv, const mat4 projInv, const vec2 uv, const float depth) {
	vec4 relPos = modelViewInv * getViewPos(projInv, uv, depth);
	
	return relPos / relPos.w;
}

// Based on one by Chocapic13
vec3 getRayTraceFactor(const sampler2D depthTex, const mat4 proj, const mat4 projInv, const vec3 viewPos, const vec3 reflectPos) {
	const int refinementSteps = 3;
	const int raySteps = 32;

	vec3 rayTracePosHit = vec3(0.0);
	
	vec3 refPos = reflectPos;
	vec3 startPos = viewPos + refPos + 0.05;
	vec3 tracePos = refPos;

    int sr = 0;
    for (int i = 0; i < raySteps; i++) {
        vec4 uv = proj * vec4(startPos, 1.0);
        uv.xyz = uv.xyz / uv.w * 0.5 + 0.5;
       
	    if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1 || uv.z < 0 || uv.z > 1.0) {
			break;
		}

        vec3 viewPosAlt = getViewPos(projInv, uv.xy, texture2D(depthTex, uv.xy).x).xyz;
		if (distance(startPos, viewPosAlt) < length(refPos) * pow(length(tracePos), 0.1)) {
			sr++;
			if (sr >= refinementSteps) {
				rayTracePosHit = vec3(uv.xy, 1.0);
				break;
			}

			tracePos -= refPos;
			refPos *= 0.07;
        }

        refPos *= 2.0;
        tracePos += refPos;
		startPos = viewPos + tracePos;
	}

    return rayTracePosHit;
}

void main() {
vec3 albedo = texture2D(gcolor, uv).rgb;
vec4 normal = texture2D(gnormal, uv);
normal.rgb = normal.rgb * 2.0 - 1.0;
float depth = texture2D(depthtex0, uv).r;
vec3 viewPos = getViewPos(gbufferProjectionInverse, uv, depth).xyz;
vec3 relPos = getRelPos(gbufferModelViewInverse, gbufferProjectionInverse, uv, depth).xyz;
vec3 fragPos = relPos + cameraPosition;
float cosTheta = abs(dot(normalize(relPos), normal.rgb));
vec3 skyPos = reflect(normalize(relPos), normal.rgb);
vec3 sky = mix(skyColor, fogColor, smoothstep(0.8, 1.0, 1.0 - skyPos.y));

if (normal.a > 0.0) {
    vec3 refPos = reflect(normalize(viewPos), mat3(gbufferModelView) * normal.rgb);
    vec3 rayTracePosHit = getRayTraceFactor(depthtex0, gbufferProjection, gbufferProjectionInverse, viewPos, refPos);
    
    vec3 reflection = sky;
    if (rayTracePosHit.z > 0.5) {
        reflection = texture2D(gcolor, rayTracePosHit.xy).rgb;
    }

    albedo = mix(reflection, albedo, cosTheta);
}

    /* DRAWBUFFERS:0
     * 0 = gcolor
     * 1 = gdepth
     * 2 = gnormal
     * 3 = composite
     * 4 = gaux1
     * 5 = gaux2
     * 6 = gaux3
     * 7 = gaux4
    */
	gl_FragData[0] = vec4(albedo, 1.0); // gcolor
}