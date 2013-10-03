
#ifdef GL_ES
precision lowp float;
#endif

varying vec4 v_fragmentColor;
varying vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_parentAlpha;
#ifdef GL_ES
uniform highp float u_matrix[20];
uniform highp float u_glowSize;
#else
uniform float u_matrix[20];
uniform float u_glowSize;
#endif
uniform float u_glowStrenght;
uniform vec3 u_glowColor;



void main()
{
	vec4 color = v_fragmentColor * texture2D(u_texture, v_texCoord);
	color.a *= u_parentAlpha;

	vec4 clr;
	 
	clr.r = dot(color, vec4(u_matrix[0], u_matrix[1], u_matrix[2], u_matrix[3])) + u_matrix[4];
	clr.g = dot(color, vec4(u_matrix[5], u_matrix[6], u_matrix[7], u_matrix[8])) + u_matrix[9];
	clr.b = dot(color, vec4(u_matrix[10], u_matrix[11], u_matrix[12], u_matrix[13])) + u_matrix[14];
	clr.a = dot(color, vec4(u_matrix[15], u_matrix[16], u_matrix[17], u_matrix[18])) + u_matrix[19];

	if (clr.a < 0.8)
	{
		vec4 sum = vec4(0.0,0.0,0.0,0.0); 

		float k2 = u_glowStrenght;
		 
		sum += texture2D(u_texture, vec2(v_texCoord.x, v_texCoord.y - 3.0*u_glowSize)) * u_glowStrenght; 
		sum += texture2D(u_texture, vec2(v_texCoord.x, v_texCoord.y - 2.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x, v_texCoord.y - u_glowSize)) * k2;
			
		sum += texture2D(u_texture, vec2(v_texCoord.x, v_texCoord.y + u_glowSize)) * k2;
		sum += texture2D(u_texture, vec2(v_texCoord.x, v_texCoord.y + 2.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x, v_texCoord.y + 3.0*u_glowSize)) * u_glowStrenght;
			
		sum += texture2D(u_texture, vec2(v_texCoord.x - 3.0*u_glowSize, v_texCoord.y)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x - 2.0*u_glowSize, v_texCoord.y)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x - u_glowSize, v_texCoord.y)) *k2;
		
		sum += texture2D(u_texture, vec2(v_texCoord.x + u_glowSize, v_texCoord.y)) * k2;
		sum += texture2D(u_texture, vec2(v_texCoord.x + 2.0*u_glowSize, v_texCoord.y)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x + 3.0*u_glowSize, v_texCoord.y)) * u_glowStrenght;
		
		sum += texture2D(u_texture, vec2(v_texCoord.x - 3.0*u_glowSize, v_texCoord.y - 3.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x - 2.0*u_glowSize, v_texCoord.y- 2.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x - u_glowSize, v_texCoord.y- u_glowSize)) * k2;
		
		sum += texture2D(u_texture, vec2(v_texCoord.x + u_glowSize, v_texCoord.y+ u_glowSize)) * k2;
		sum += texture2D(u_texture, vec2(v_texCoord.x + 2.0*u_glowSize, v_texCoord.y+ 2.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x + 3.0*u_glowSize, v_texCoord.y+ 3.0*u_glowSize) ) * u_glowStrenght;
		
		sum += texture2D(u_texture, vec2(v_texCoord.x - 3.0*u_glowSize, v_texCoord.y + 3.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x - 2.0*u_glowSize, v_texCoord.y+ 2.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x - u_glowSize, v_texCoord.y+ u_glowSize)) * k2;
		
		sum += texture2D(u_texture, vec2(v_texCoord.x + u_glowSize, v_texCoord.y- u_glowSize)) * k2;
		sum += texture2D(u_texture, vec2(v_texCoord.x + 2.0*u_glowSize, v_texCoord.y- 2.0*u_glowSize)) * u_glowStrenght;
		sum += texture2D(u_texture, vec2(v_texCoord.x + 3.0*u_glowSize, v_texCoord.y- 3.0*u_glowSize))  * u_glowStrenght;

		
		sum.r = u_glowColor.r * sum.a;
		sum.g = u_glowColor.g * sum.a;
		sum.b = u_glowColor.b * sum.a;   
		clr = sum;
	}

	gl_FragColor = clr;

}
