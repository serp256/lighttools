OCAMLBUILD = ocamlbuild -use-ocamlfind -lflag "-g"
TARGET = resmkr.native 

arm:
	rm -f $(TARGET)
	$(OCAMLBUILD) $(TARGET)

clean:
	$(OCAMLBUILD) -clean

test:
	./$(TARGET) -concat -i ~/projects/word/light-client/src/android/assets -o pizda
	./$(TARGET) -extract -i pizda -fname imgs/init-screen-photosnormal_hdpi.png -o pizda.png
