rebuild:
	make -C .. clean
	make -C ..

test1:
	./fontmaker -c 2 -s 24 -o 1 CCFairyTale.otf

test2:
	./fontmaker -c QWERTYUIOPASDFGHJKLZXCVBNM1234567890 -s 24 -o 2 Arial.ttf

1:
	open 1/CCFairyTale_0.png

2:
	open 2/CCFairyTale_0.png	

.PHONY: 1 2