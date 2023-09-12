#ifndef __DISPLAY3_HFILE
#define __DISPLAY3_HFILE

#include "avrio.h"

class Display3 {
public:

    byte locx, locy;
    byte attr;

    void color(byte x) { attr = x; }

    // Очистка экрана от скверны
    void cls(byte _attr = 0x07) {

        heapvm;
        bank(0);

        outp(VMODE, VM_80x25);

        attr = _attr;
        locate(0, 0);

        for (int i = 0; i < 4000; i+= 2) {
            vm[i]   = 0x00;
            vm[i+1] = _attr;
        }
    }

    // Установка курсора
    void locate(byte x, byte y) {

        locx = x;
        locy = y;

        outp(CURX, x);
        outp(CURY, y);
    }

    // Пропечать одного символа
    void prn(char m) {

        heapvm;
        bank(0);

        if (m == 10) {
            locx = 80;
        } else {
            int loc = 2*locx + locy*160;
            vm[loc]   = m;
            vm[loc+1] = attr;
        }

        locx++;
        if (locx >= 80) {
            locx = 0;
            locy++;
            if (locy >= 25) {
                locy = 24;
            }
        }

        locate(locx, locy);
    }

    void put(byte x, byte y, byte ch) {

        heapvm;
        int loc = 2*x + y*160;
        vm[loc]   = ch;
        vm[loc+1] = attr;
    }

    // Печать символов на экране
    int print(const char* m) {

        int i = 0;
        while (m[i]) prn(m[i++]);
        return i;
    }

    // Печать строки из Program memory
    int print_pgm(const char* m) {

        int i = 0;
        char ch;
        while ((ch = pgm_read_byte(& m[i++]))) prn(ch);
        return i;
    }

    // Печать числа от -32767 до 32767
    void prnint(int x) {

        int  id = 0;
        char t[6];

        if (x < 0) { prn('-'); x = -x; }
        do { int a = x % 10; x = x / 10; t[id++] = '0' + a; } while (x);
        while (--id >= 0) prn(t[id]);
    }

    void prnhex(int x) {

        byte k;

        k = (x >> 4) & 15;
        prn(k < 10 ? '0' + k : '7' + k);
        k = x & 15;
        prn(k < 10 ? '0' + k : '7' + k);
    }

    // Рисовать фрейм
    void frame(char x1, char y1, char x2, char y2, char density) {

        int i;
        char v = density ? 0xBA : 0xB3;
        char h = density ? 0xCD : 0xC4;

        for (i = x1 + 1; i < x2; i++) { put(i, y1, h); put(i, y2, h); }
        for (i = y1 + 1; i < y2; i++) { put(x1, i, v); put(x2, i, v); }

        if (density) {

            put(x1, y1, 0xC9); put(x2, y1, 0xBB);
            put(x1, y2, 0xC8); put(x2, y2, 0xBC);

        } else {

            put(x1, y1, 0xDA); put(x2, y1, 0xBF);
            put(x1, y2, 0xC0); put(x2, y2, 0xD9);
        }
    }

    // Рисование блока текста
    void block(char x1, char y1, char x2, char y2, unsigned char cl) {

        for (int i = y1; i <= y2; i++)
        for (int j = x1; j <= x2; j++)
            put(j, i, ' ');
    }

};

#endif
