


all: 
	ocamlbuild -use-ocamlfind calcimages.byte

alln: 
	ocamlbuild -use-ocamlfind calcimages.native

%.byte:
	ocamlbuild -use-ocamlfind $@

%.native:
	ocamlbuild -use-ocamlfind $@

clean:
	ocamlbuild -use-ocamlfind -clean
