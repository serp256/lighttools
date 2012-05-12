BUILDER = ocamlbuild -use-ocamlfind -classic-display

all: 
	$(BUILDER) convert.native

clean:
	ocamlbuild -use-ocamlfind -clean

lib:
	cp -r input/* 1/
	mv 1/tl_* 2/
	rm -r output/*
	./convert.native -inp 1 -pvr 
	./convert.native -inp 2 -n 100500 -min 512 -pvr


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

