#!/bin/bash

OCB="ocamlbuild -classic-display -use-ocamlfind -I ~/Projects/lightning/src"
target=showllib

case $1 in
	clean) $OCB -clean ;;
	*) $OCB ${target}.byte 
esac
