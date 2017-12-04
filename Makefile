all: playMusic

playMusic: playMusic.c EasyPIO.h note.h bach.h canon.h sleigh.h
	gcc -g -pthread -o playMusic playMusic.c -lpigpio -lrt -lwiringPi -lpthread

clean: 
	rm playMusic