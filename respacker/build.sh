#!/bin/bash

OCB="ocamlbuild -use-ocamlfind"
target=respacker

case $1 in
	clean) $OCB -clean ;;
	byte) $OCB ${target}.byte ;;
	*) $OCB $target.native
esac
	
#ocamlbuild -use-ocamlfind respacker.native
