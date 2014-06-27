default: compile run

compile:
	amxmlc -debug=true -swf-version 21 -library-path+=lib src/Rasterizer.mxml -output=bin/rasterizer.swf

run:
	adl rasterizer-app.xml

cert:
	adt -certificate -cn RasterizerCert -o "Redspell" -c RU 2048-RSA cert/rasterizer.p12 xyupizda

air:
	adt -package -storetype pkcs12 -keystore cert/rasterizer.p12 bin/rasterizer.air rasterizer-app.xml bin/rasterizer.swf

.PHONY: cert