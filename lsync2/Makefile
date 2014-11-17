all: lsync2 lsync2lib

lsync2:
	ocamlbuild -use-ocamlfind -lflag -g lsync2.native

lsync2lib:
	ocamlbuild -use-ocamlfind lsync2lib.cmo

install:
	sudo ocamlfind install lsync2lib META _build/lsync2lib.cmo _build/lsync2lib.cmi
	sudo cp lsync2.native /usr/bin/lsync2

uninstall:
	sudo ocamlfind remove lsync2lib

reinstall: uninstall install

clean:
	ocamlbuild -clean
