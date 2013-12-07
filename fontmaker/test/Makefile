rebuild:
	make -C .. clean
	make -C ..

test1:
	./fontmaker -c 1234567890QWERTYUIOPASDFGHJKLZXCVBNM -s 20,25,30,40,100 -o 1 CCFairyTale.otf

test2:
	./fontmaker -c 1234567890QWERTYUIOPASDFGHJKLZXCVBNM -s 15 -o 2 CCFairyTale.otf

1:
	open 1/CCFairyTale_0.png

2:
	open 2/CCFairyTale_0.png	

.PHONY: 1 2