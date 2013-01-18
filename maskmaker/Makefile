OBLD=ocamlbuild -use-ocamlfind  -classic-display -Xs Resources,ColouristRasterizer,paint_mixing

maskmaker:
	$(OBLD) maskmaker.native

clean: android-clean ios-clean
	$(OBLD) -clean
	rm -rf _build_android
	rm -rf img/0* img/1* img/2* img/3* img/4* img/5* img/6* img/7* img/8* img/9*

android: android-bin android-resources
	cd android && ant debug

android-bin:
	$(OBLD) -build-dir _build_android game.so
	mkdir -p android/libs/armeabi-v7a
	mv _build_android/game.so android/libs/armeabi-v7a/libdrawer.so

android-resources:
	rm -rf android/assets/*
	cp -r Resources/* android/assets/

android-clean:
	rm -fr android/bin android/libs android/gen

android-install:
	adb install -r android/bin/Drawer-debug.apk

ios:
	$(OBLD) -plugin-option -toolchain ios -plugin-option -native-only -build-dir _build_ios game.native
	mv _build_ios/game.native ios/ColouringBin

ios-clean:
	$(OBLD) -build-dir _build_ios -clean

%.cmo:
	$(OBLD) $@

%.byte:
	$(OBLD) $@

.PHONY: ios android
