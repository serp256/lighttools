
#ifdef GL_ES
precision lowp float;
#endif

varying vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_strength;
uniform vec3 u_color;
uniform float u_parentAlpha; 

void main(void)
{
	float alpha = texture2D(u_texture,v_texCoord).a;
	if (alpha < 1.0) {
		alpha = clamp(alpha * u_strength,0.,1.);
		gl_FragColor = vec4(u_color,alpha * u_parentAlpha);
	} else {
		gl_FragColor = vec4(0.,0.,0.,0.);
	}
}
