BUILDER = ocamlbuild -use-ocamlfind -classic-display

all: 
	$(BUILDER) convert.native

clean:
	ocamlbuild -use-ocamlfind -clean

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

