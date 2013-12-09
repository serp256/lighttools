rebuild:
	make -C .. clean
	make -C ..

test1:
	./fontmaker -c QWERTYUIOPASDFGHJKLZXCVBNM1234567890 -s 30 -o 1 Arial.ttf

test2:
	./fontmaker -c 1234567890QWERTYUIOPASDFGHJKLZXCVBNM -s 20,25,30,40,100 -o 2 Arial.ttf

1:
	open 1/CCFairyTale_0.png

2:
	open 2/CCFairyTale_0.png	

.PHONY: 1 2