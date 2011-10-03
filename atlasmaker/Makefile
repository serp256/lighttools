BUILDER = /usr/local/bin/ocamlbuild -use-ocamlfind -classic-display

all: 
	ocamlbuild -use-ocamlfind atlasmaker.native

animate:
	$(BUILDER) animatemaker.native

byte:
	ocamlbuild -use-ocamlfind atlasmaker.byte

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
