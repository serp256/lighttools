BUILDER = ocamlbuild -use-ocamlfind -classic-display
SCALE=0.5


all: 
	$(BUILDER) convert.native

clean:
	ocamlbuild -use-ocamlfind -clean

lib_test:
	rm -r 1/*
	rm -r 2/*
	rm -r 3/*
	cp -r input/* 1/
	mv 1/tl_* 2/
	mv 1/bk_furrow 2/
	mv 1/*_ex 3/
	rm -r ~/Devel/mobile-farm/Resources/library/*
	./convert.native -inp 1 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library
	./convert.native -inp 2 -n 100500 -min 512 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library
	./convert.native -inp 3 -n 1000 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library
	./convert.native -inp 1 -o ~/Devel/mobile-farm/Resources/library
	./convert.native -inp 2 -n 100500 -min 512 -o ~/Devel/mobile-farm/Resources/library
	./convert.native -inp 3 -n 1000 -o ~/Devel/mobile-farm/Resources/library

lib_05:
	rm -r 1/*
	rm -r 2/*
	cp -r input/* 1/
	mv 1/tl_* 2/
	mv 1/bk_furrow 2/
	./convert.native -inp 1 -scale 0.5 -o ~/Devel/mobile-farm/Resources/library
	./convert.native -inp 2 -n 100500 -min 512 -scale 0.5 -o ~/Devel/mobile-farm/Resources/library


lib:
	rm -r 1/*
	rm -r 2/*
	rm -r 3/*
	cp -r input/* 1/
	mv 1/tl_* 2/
	mv 1/bk_furrow 2/
	mv 1/*_ex 3/
	rm -r ~/Devel/mobile-farm/Resources/library/* 
	./convert.native -inp 1 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 2 -n 100500 -min 512 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 3 -n 1000 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 1 -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 2 -n 100500 -min 512 -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 3 -n 1000 -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 1 -o ~/Devel/mobile-farm/Resources/library -dxt
	./convert.native -inp 2 -n 100500 -min 512 -o ~/Devel/mobile-farm/Resources/library -dxt
	./convert.native -inp 3 -n 1000 -o ~/Devel/mobile-farm/Resources/library -dxt

100500:
	./convert.native -inp 2 -n 100500 -min 512 -scale ${SCALE} -o ~/Devel/mobile-farm/Resources/library -pvr
	./convert.native -inp 2 -n 100500 -min 512 -o ~/Devel/mobile-farm/Resources/library -pvr



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

