#include <avrio.h>
#include <display3.h>
#include <display13.h>
#include <displayzx.h>

#include "scr/wall_1.h"

// Текстовый экран
void hello_3() {

    Display3 D;

    D.cls(0x07);
    for (int i = 0; i < 1000; i++) D.print("/\\");

    D.attr = 0x17;
    D.locate(34, 12);
    D.print("HELLO WORLD!");
}

// Экран 320x200
void hello_13() {

    Display13 D;
    D.cls(4);

    for (int y = 0; y < 200; y++)
    for (int x = 0; x < 320; x++)
        D.pset(x, y, x*y>>8);
}

// Спектрум-экран
void hello_zx() {

    DisplayZX D;
    D.cls();

    heapzx;
    for (int i = 0; i < 6912; i++) vm[i] = pgm_read_byte(&WALLPAPER[i]);

    outp(ZXBORD, 1);
}

int main() {

    //hello_3();
    //hello_13();
    hello_zx();
}
