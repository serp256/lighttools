
attribute vec4 a_position;
attribute vec4 a_color;
attribute vec2 a_texCoord;

uniform		mat4 u_MVPMatrix;

varying vec4 v_fragmentColor;
varying vec2 v_texCoord;

void main()
{
	gl_Position = u_MVPMatrix * a_position;
	v_fragmentColor = a_color;
	v_texCoord = a_texCoord;
}
