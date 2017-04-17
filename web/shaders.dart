/*
Copyright Robert Muth <robert@muth.org>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; version 3
of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

library pc_shaders;

import 'package:chronosgl/chronosgl.dart';

const String iaRotatationY = "iaRotatationY";
const String uFogColor = "uFogColor";
const String uFogEnd = "uFogEnd";
const String uFogScale = "uFogScale";

List<ShaderObject> pcPointSpritesShader() {
  return [
    new ShaderObject("PointSprites")
      ..AddAttributeVars([aVertexPosition, aPointSize, aColor])
      ..AddVaryingVars([vColor])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..SetBodyWithMain([
        StdVertexBody,
        "${vColor} = ${aColor};",
        "gl_PointSize = ${aPointSize}/gl_Position.z;"
      ]),
    new ShaderObject("PointSpritesF")
      ..AddVaryingVars([vColor])
      ..AddUniformVars([uTexture])
      ..SetBodyWithMain([
        """
        vec4 c = texture2D( ${uTexture},  gl_PointCoord);
        gl_FragColor = c * vec4(${vColor}, 1.0 );
        """
      ])
  ];
}

List<ShaderObject> pcPointSpritesFlashingShader() {
  return [
    new ShaderObject("PointSpritesFlashing")
      ..AddAttributeVars([aVertexPosition, aPointSize, aColor])
      ..AddVaryingVars([vColor, vVertexPosition])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..SetBodyWithMain([
        StdVertexBody,
        "${vColor} = ${aColor};",
        "gl_PointSize = ${aPointSize}/gl_Position.z;",
        "${vVertexPosition} = ${aVertexPosition};"
      ]),
    new ShaderObject("PointSpritesF")
      ..AddVaryingVars([vColor, vVertexPosition])
      ..AddUniformVars([uTexture, uTime])
      ..SetBodyWithMain([
        """
        vec4 color = texture2D( ${uTexture},  gl_PointCoord);
        float noise1 = 10.0 * sin(${vVertexPosition}.x + ${vVertexPosition}.z);
        float noise2 = 1.0 + 0.2 *  sin(${vVertexPosition}.x + ${vVertexPosition}.z);
        float intensity = 0.5 + 0.5 * sin(noise1 + ${uTime} * noise2);
        gl_FragColor = color * intensity * vec4(${vColor}, 1.0 );
        """
      ])
  ];
}

List<ShaderObject> pcTexturedShaderWithFog() {
  return [
    new ShaderObject("Textured")
      ..AddAttributeVars([aVertexPosition, aTextureCoordinates, aColor])
      ..AddVaryingVars([vColor, vVertexPosition, vTextureCoordinates])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..SetBodyWithMain([
        StdVertexBody,
        "${vTextureCoordinates} = ${aTextureCoordinates};",
        "${vColor} = ${aColor};",
        "${vVertexPosition} = (${uModelMatrix} * vec4(${aVertexPosition}, 1.0)).xyz;"
      ]),
    new ShaderObject("TexturedF")
      ..AddVaryingVars([vVertexPosition, vColor, vTextureCoordinates])
      ..AddUniformVars([uTexture])
      ..AddUniformVars([uFogColor, uFogEnd, uFogScale])
      ..SetBodyWithMain([
        """
        vec4 c = texture2D(${uTexture}, ${vTextureCoordinates});
        c = c * vec4(${vColor}, 1.0 );
        float f =  clamp((uFogEnd - length(${vVertexPosition})) * uFogScale, 0.0, 1.0);
        c = mix(vec4(uFogColor, 1.0), c, f);
        gl_FragColor = c;
        """
      ])
  ];
}

List<ShaderObject> pcTexturedShader() {
  return [
    new ShaderObject("Textured")
      ..AddAttributeVars([aVertexPosition, aTextureCoordinates, aColor])
      ..AddVaryingVars([vColor, vVertexPosition, vTextureCoordinates])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..SetBodyWithMain([
        StdVertexBody,
        "${vTextureCoordinates} = ${aTextureCoordinates};",
        "${vColor} = ${aColor};",
        "${vVertexPosition} = (${uModelMatrix} * vec4(${aVertexPosition}, 1.0)).xyz;"
      ]),
    new ShaderObject("TexturedF")
      ..AddVaryingVars([vVertexPosition, vColor, vTextureCoordinates])
      ..AddUniformVars([uTexture])
      ..SetBodyWithMain([
        """
        vec4 c = texture2D(${uTexture}, ${vTextureCoordinates});
        c = c * vec4(${vColor}, 1.0 );
        gl_FragColor = c;
        """
      ])
  ];
}

List<ShaderObject> pcTexturedShaderWithInstancer() {
  return [
    new ShaderObject("InstancedV")
      ..AddAttributeVars([aVertexPosition, aTextureCoordinates, aColor])
      ..AddVaryingVars([vColor, vTextureCoordinates])
      ..AddAttributeVars([iaRotatationY, iaTranslation])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..SetBody([
        """
vec3 rotate_position(vec3 pos, vec4 rot) {
  return pos + 2.0 * cross(rot.xyz, cross(rot.xyz, pos) + rot.w * pos);
}

mat4 rotationMatrix(vec3 axis, float angle) {
    vec3 a = normalize(axis);
    float x = a.x;
    float y = a.y;
    float z = a.z;
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat4(oc * x * x + c,      oc * x * y - z * s,  oc * z * x + y * s,  0.0,
                oc * x * y + z * s,  oc * y * y + c,      oc * y * z - x * s,  0.0,
                oc * z * x - y * s,  oc * y * z + x * s,  oc * z * z + c,      0.0,
                0.0,                 0.0,                 0.0,                 1.0);
}


void main(void) {
  mat4 roty = rotationMatrix(vec3(0, 1, 0),  ${iaRotatationY});
  vec4 P = roty * vec4(${aVertexPosition}, 1) + vec4(${iaTranslation}, 0);
  gl_Position = ${uPerspectiveViewMatrix} * ${uModelMatrix} * P;
  ${vColor} = ${aColor};
  ${vTextureCoordinates} = ${aTextureCoordinates};
}
"""
      ]),
    new ShaderObject("TexturedF")
      ..AddVaryingVars([vColor, vTextureCoordinates])
      ..AddUniformVars([uTexture])
      ..SetBodyWithMain([
        "gl_FragColor = texture2D(${uTexture}, ${vTextureCoordinates}) * vec4( ${vColor}, 1.0 );"
      ])
  ];
}

List<ShaderObject> pcTexturedShaderWithShadow() {
  return [
    new ShaderObject("Textured")
      ..AddAttributeVars([aVertexPosition, aTextureCoordinates, aColor])
      ..AddVaryingVars([vColor, vTextureCoordinates, vPositionFromLight])
      ..AddUniformVars(
          [uPerspectiveViewMatrix, uModelMatrix, uLightPerspectiveViewMatrix])
      ..SetBodyWithMain([
        """
        vec4 pos = ${uModelMatrix} * vec4(${aVertexPosition}, 1.0);
        gl_Position = ${uPerspectiveViewMatrix} * pos;
        ${vPositionFromLight} = ${uLightPerspectiveViewMatrix} * pos;
        ${vTextureCoordinates} = ${aTextureCoordinates};
        ${vColor} = ${aColor};
      """
      ]),
    new ShaderObject("TexturedF")
      ..AddVaryingVars([vColor, vTextureCoordinates, vPositionFromLight])
      ..AddUniformVars([uTexture, uShadowMap, uCanvasSize])
      ..SetBody([
        ShadowMapPackedRGBA.GetShadowMapValueLib(),
        ShadowMapShaderLib,
        """
float XGetShadowPCF16(
    vec3 depth, sampler2D shadowMap, vec2 mapSize, float bias) {
    vec2 uv = depth.xy;
    float d = 0.0;
    for(float dx = -1.5; dx <= 1.5; dx += 1.0) {
        for(float dy =-1.5; dy <= 1.5; dy += 1.0) {
             if (depth.z - GetShadowMapValue(shadowMap, uv + vec2(dx, dy)) > bias) {
               d += 1.0 / 16.0;
             }
        }
    }
    return 1.0 - d;
}


float bias1 = 0.001;
float bias2 = 0.001;

void main() {
    vec3 depth = ${vPositionFromLight}.xyz / ${vPositionFromLight}.w;
                 // depth is in [-1, 1] but we want [0, 1] for the texture lookup
    depth = 0.5 * depth + vec3(0.5);

    //float shadow = XGetShadowPCF16(depth, ${uShadowMap}, ${uCanvasSize}, bias1);
    float shadow = GetShadowPCF16(depth, ${uShadowMap}, ${uCanvasSize}, bias1, bias2);

    shadow = shadow * 0.7 + 0.3;
    vec4 c = texture2D(${uTexture}, ${vTextureCoordinates});
    gl_FragColor = c * shadow * vec4(${vColor}, 1.0 );
}
"""
      ])
  ];
}
