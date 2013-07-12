-include config.local

BUILDER = ocamlbuild -use-ocamlfind -classic-display
SCALE=0.5
LIB_DIR?=libs

all: 
	$(BUILDER) convert.native

clean:
	ocamlbuild -use-ocamlfind -clean

lib_05:
	rm -r -f 1/*
	rm -r -f  2/*
	cp -r  input/* 1/
	mv 1/tl_* 2/
	mv 1/bk_furrow 2/
	./convert.native -inp 1 -scale 0.5 -o ~/Devel/mobile-farm/Resources/library
	./convert.native -inp 2 -n 100500 -min 512 -scale 0.5 -o ~/Devel/mobile-farm/Resources/library

prepare-input:
	-rm -r -f 1/*
	-rm -r -f 2/*
#	-rm -r -f 3/*
	cp -r input/* 1/
	mv 1/tl_* 2/
	mv 1/bk_furrow 2/
#	mv 1/*_ex 3/

clean-output:
	rm -r -f ${LIB_DIR}/*

#lib-compressed:
#	./convert.native -inp 2 -n 100500 -wholly -scale 2 -o ${LIB_DIR} -pvr
#	./convert.native -inp 1 -degree4 -scale 2 -o ${LIB_DIR} -pvr
#	./convert.native -inp 2 -n 100500 -wholly -scale 0.5 -o ${LIB_DIR} -pvr
#	./convert.native -inp 1 -degree4 -scale 0.5 -o ${LIB_DIR} -pvr
#	./convert.native -inp 2 -n 100500 -wholly -o ${LIB_DIR} -pvr -dxt
#	./convert.native -inp 1 -degree4 -o ${LIB_DIR} -pvr -dxt

lib-compressed:
	./convert.native -max 4096 -pvr -dxt -degree4 -scale 2 -o ${LIB_DIR} conf/farm.json
	./convert.native -min 512 -max 2048 -no-anim -degree4 -pvr -dxt -scale ${SCALE} -o ${LIB_DIR} conf/farm.json
	./convert.native -max 2048 -degree4 -pvr -dxt -o ${LIB_DIR} conf/farm.json

lib: clean-output lib-compressed

#lib-notcompressed:
#	./convert.native -inp 2 -wholly -n 100500 -scale ${SCALE} -o ${LIB_DIR} 
#	./convert.native -inp 1 -degree4 -scale ${SCALE} -o ${LIB_DIR} 
#	./convert.native -inp 2 -wholly -n 100500 -o ${LIB_DIR} 
#	./convert.native -inp 1 -degree4 -o ${LIB_DIR} -o ${LIB_DIR} 
#	./convert.native -max 4096 -inp 2 -wholly -n 100500 -scale 2 -o ${LIB_DIR} 
#	./convert.native -max 4096 -inp 1 -degree4 -scale 2 -o ${LIB_DIR} 

lib-notcompressed:
	./convert.native -degree4 -scale ${SCALE} -o ${LIB_DIR} conf/farm.json
	./convert.native -degree4 -o ${LIB_DIR} conf/farm.json
	./convert.native -max 2048  -degree4 -scale 2 -o ${LIB_DIR} conf/farm.json

#lib-test: prepare-input clean-output lib-notcompressed
lib-test: clean-output lib-notcompressed
lib-testx1: 
	rm -r -f output/*
	./convert.native -min 512 -max 2048 -pvr -degree4 conf/farm.json

lib-testx2: 
	rm -r -f output/*
	./convert.native -min 1024 -android -max 2048 -degree4 -scale 2 conf/farm.json

lib-testx05: 
	rm -r -f output/*
	./convert.native -no-anim -min 512 -max 2048 -degree4 -pvr -scale 0.5 conf/farm.json

lib-testx2_: 
	rm -r -f output/*
	./convert.native -without-cntr -max 2048 -degree4 -scale 2 conf/farm.json

lib-test: clean-output lib-notcompressed

100500:
	./convert.native -inp 2 -n 100500 -min 512 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 2 -n 100500 -min 512 -o ~/Devel/mobile-farm/Resources/library -pvr

100500-test: prepare-input
	./convert.native -wholly -inp 2 -n 100500 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library
	./convert.native -wholly -inp 2 -n 100500 -scale 2 -o ~/Devel/mobile-farm/Resources/library
	./convert.native -wholly -inp 2 -n 100500 -o ~/Devel/mobile-farm/Resources/library 




%.cmo:
	  $(BUILDER) $@
%.byte:
	  $(BUILDER) $@
%.cmx:
	  $(BUILDER) $@
%.cmxa:
	  $(BUILDER) $@
%.native: %.ml
	  $(BUILDER) $@
%.o: %.c
	  $(BUILDER) $@
%.cma:
	  $(BUILDER) $@

