#version 120

attribute vec4 at_tangent;
attribute vec3 mc_Entity;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform vec3 cameraPosition;

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

void main() {
uv0 = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
uv1 = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
col = gl_Color;
waterFlag = int(mc_Entity.x) == 10000 ? 1.0 : 0.0;
viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
relPos  = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
fragPos = relPos + cameraPosition;
tangent   = normalize(gl_NormalMatrix * at_tangent.xyz);
binormal  = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
normal    = normalize(gl_NormalMatrix * gl_Normal);
tbnMatrix = transpose(mat3(tangent, binormal, normal));

	gl_Position = ftransform();
}