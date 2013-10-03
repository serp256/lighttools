#ifdef GL_ES
precision lowp float;
#endif

varying vec4 v_fragmentColor;
varying vec2 v_texCoord;
uniform sampler2D u_texture;
uniform sampler2D u_pallete;
uniform float u_parentAlpha;

void main()
{
#ifdef GL_ES
	mediump vec4 idx = texture2D(u_texture,v_texCoord);
#else
	vec4 idx = texture2D(u_texture,v_texCoord);
#endif
	// вычислить сцука индекc нахуй
	// vec4 color = v_fragmentColor * texture2D(u_pallete,vec2((idx.r * 255.)  / 256., idx.a));
	// float x = ((idx.r * 255.) + 0.5) / 256.;
	// float y = ((idx.a * 255.) + 0.5) / 256.;
	// float x = 0; float y = 0;
	vec4 color = v_fragmentColor * texture2D(u_pallete,vec2(idx.r * 0.99609375 + 0.001953125,idx.a * 0.99609375 + 0.001953125));
	//vec4 color = v_fragmentColor * texture2D(u_pallete,vec2(idx.r, idx.a));
	//vec4 color = v_fragmentColor * texture2D(u_pallete, vec2(idx.r,idx.a));
	gl_FragColor = color * u_parentAlpha; 
}
