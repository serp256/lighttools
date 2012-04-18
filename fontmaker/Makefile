COMMON_PARAMS = -alpha -s 10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25 -o ~/projects/mobile-farm/Resources/fonts
CHARS = $(COMMON_PARAMS) -c "@\#$$\%^&*()_+-=<>|/!?\"'№:,.;{}[]qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNMйцукенгшщзхъёфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪЁФЫВАПРОЛДЖЭЯЧСМИТЬБЮ1234567890" 
DIGIT_CHARS = $(COMMON_PARAMS) -c "x1234567890/:"
BIN = fontmaker.native
ifdef scale
SCALE = -scale $(scale)
else
SCALE =
endif

all: 
	ocamlbuild -use-ocamlfind $(BIN) 

clean:
	ocamlbuild -use-ocamlfind -clean

font:
	./$(BIN) $(CHARS) $(SCALE) $(path) 

digits:
	./$(BIN) $(DIGIT_CHARS) $(SCALE) $(path) 
