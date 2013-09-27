all: build install

build:
	ocamlbuild -use-ocamlfind -lflag -g mpcttr.byte

clean:
	ocamlbuild -clean

install:
	cp mpcttr.byte ~/bin/mpcttr

test: all
	mpcttr -size 4096 -i ~/projects/steampunk/mobile_client/Resources/map_bg.png -o ~/projects/steampunk/mobile_client/Resources/map