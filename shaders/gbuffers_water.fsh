#version 120

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D noisetex;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform float frameTimeCounter;

varying vec2 uv0;
varying vec2 uv1;
varying vec4 col;
varying vec3 viewPos;
varying vec3 relPos;
varying vec3 fragPos;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 normal;
varying mat3 tbnMatrix;
flat varying float waterFlag;

const int noiseTextureResolution = 256;

float textureNoise(const vec2 pos) {
    return texture2D(noisetex, pos / float(noiseTextureResolution)).r;
}

#define ENABLE_WATER_WAVES
float getWaterWav(const vec2 pos, const float time) {
	float wav = 0.0;
#   if defined ENABLE_WATER_WAVES
		vec2 p = pos * 2.0;
		
		wav += textureNoise(vec2(p.x * 1.4 + time * 0.8, p.y * 1.2));
		wav += textureNoise(vec2(p.x * 0.8 - time * 0.6, p.y * 1.2));
		wav += textureNoise(vec2(p.x * 1.2,              p.y * 0.6 + time * 1.8));
		wav += textureNoise(vec2(p.x * 0.7,              p.y * 1.3 - time * 1.2));
		wav += textureNoise(vec2(p.x * 1.6 + time * 1.3, p.y * 1.8 - time * 1.2));
		wav += textureNoise(vec2(p.x * 0.5 - time * 0.8, p.y * 0.9 + time * 0.5));
		wav += textureNoise(vec2(p.x * 1.2 + time * 0.7, p.y * 1.3 + time * 0.8));
		wav += textureNoise(vec2(p.x * 0.9 - time * 0.9, p.y * 0.8 - time * 0.7));

		return wav / 256.0;
#   else
        return 0.0;
#   endif
}

vec3 getWaterWavNormal(const vec2 pos, const float time) {
	const float texStep = 0.04;
    
	float height = getWaterWav(pos, time);
	vec2  delta  = vec2(height, height);

    delta.x -= getWaterWav(pos + vec2(texStep, 0.0), time);
    delta.y -= getWaterWav(pos + vec2(0.0, texStep), time);
    
	return normalize(vec3(delta / texStep, 1.0));
}

float fogify(const float x, const float w) {
	return w / (x * x + w);
}

void main() {
vec4 albedo = texture2D(texture, uv0) * col * texture2D(lightmap, uv1);
vec3 worldNormal = vec3(0.0, 1.0, 0.0);
if (waterFlag > 0.5) {
    worldNormal = normalize(getWaterWavNormal(fragPos.xz, frameTimeCounter) * tbnMatrix);
    worldNormal = mat3(gbufferModelViewInverse) * worldNormal;
}

float cosTheta = abs(dot(normalize(relPos), worldNormal));

if (waterFlag > 0.5) {
	albedo.a = mix(1.0, 0.1, cosTheta);
}

    /* DRAWBUFFERS:02
     * 0 = gcolor
     * 1 = gdepth
     * 2 = gnormal
     * 3 = composite
     * 4 = gaux1
     * 5 = gaux2
     * 6 = gaux3
     * 7 = gaux4
    */
	gl_FragData[0] = albedo; // gcolor
        gl_FragData[1] = vec4((worldNormal + 1.0) * 0.5, waterFlag); // gnormal
}