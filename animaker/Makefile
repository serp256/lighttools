BUILDER = ocamlbuild -use-ocamlfind -classic-display

all: 
	ocamlbuild -use-ocamlfind animaker.byte

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

clean: 
	ocamlbuild -clean
	rm -rf *.byte *.native
