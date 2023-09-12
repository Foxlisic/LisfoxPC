#ifndef __DISPLAY13_HFILE
#define __DISPLAY13_HFILE

#include "avrio.h"
#include "tahoma.h"

class Display13 {
public:

    // Очистка экрана от скверны
    void cls(byte color = 0x00) {

        heapvm;
        outp(VMODE, VM_320x200);

        for (int i = 0; i < 16; i++) {
            bank(i);
            for (int j = 0; j < 4096; j++) vm[j] = color;
        }
    }

    // Рисовать одну точку
    void pset(int x, int y, byte cl) {

        word t = (word)x + (word)y * 320;

        heapvm;
        bank(t >> 12);
        vm[t & 0xFFF] = cl;
    }

};

#endif
