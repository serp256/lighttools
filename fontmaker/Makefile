COMMON_PARAMS = -alpha -o ~/projects/mobile-farm/Resources/fonts
CHARS = $(COMMON_PARAMS) -s 10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,28 -c "@\#$$\%^&*()_+-=<>|/!?\"'№:,.;{}[]qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNMйцукенгшщзхъёфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪЁФЫВАПРОЛДЖЭЯЧСМИТЬБЮ1234567890" 
DIGIT_CHARS = $(COMMON_PARAMS) -s 10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,28,50 -c "x1234567890/:"
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
