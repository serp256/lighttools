


all: 
	ocamlbuild -use-ocamlfind calcimgs.byte

alln: 
	ocamlbuild -use-ocamlfind calcimgs.native

%.byte:
	ocamlbuild -use-ocamlfind $@

%.native:
	ocamlbuild -use-ocamlfind $@

clean:
	ocamlbuild -use-ocamlfind -clean
