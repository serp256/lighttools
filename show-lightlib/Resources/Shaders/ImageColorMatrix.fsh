
#ifdef GL_ES
precision lowp float;
#endif

varying vec4 v_fragmentColor;
varying vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_parentAlpha;
#ifdef GL_ES
uniform lowp float u_matrix[20];
#else
uniform float u_matrix[20];
#endif

void main()
{
	vec4 color = v_fragmentColor * texture2D(u_texture, v_texCoord);
	vec4 newcolor ; //= color;
	 
	newcolor.r = dot(color, vec4(u_matrix[0], u_matrix[1], u_matrix[2], u_matrix[3])) + u_matrix[4] * color.a;
	newcolor.g = dot(color, vec4(u_matrix[5], u_matrix[6], u_matrix[7], u_matrix[8])) + u_matrix[9] * color.a;
	newcolor.b = dot(color, vec4(u_matrix[10], u_matrix[11], u_matrix[12], u_matrix[13])) + u_matrix[14] * color.a;
	newcolor.a = dot(color, vec4(u_matrix[15], u_matrix[16], u_matrix[17], u_matrix[18])) + u_matrix[19] * color.a;

	gl_FragColor =  newcolor * u_parentAlpha;
}
