// http://www.cocos2d-iphone.org

#ifdef GL_ES
precision mediump float;
#endif

varying vec4 v_fragmentColor;
uniform float u_parentAlpha;

void main()
{
	gl_FragColor = v_fragmentColor;
	gl_FragColor.a *= u_parentAlpha;
}
