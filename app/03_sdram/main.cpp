#include <avrio.h>
#include <display3.h>
#include <kb.h>

Display3 D;
Keyboard KB;

ISR(INT1_vect) { KB.recv(); eoi; }

int main() {

    dword err = 0;

    D.cls();
    ei(2);

    D.print("WRITE\n");

    heapvm;

    // Отсюда начинается именно SDRAM: 17*4096+F000h
    for (int i = 17; i < 256; i++) {

        bank(i);
        for (int j = 0; j < 4096; j++)
            vm[j] = j & 255;

        D.locate(0, 2);
        D.print("FILL MEMORY %");
        D.prnint((100 * i) / 255);
    }

    KB.getch();

    // Проверка содержания памяти
    for (int i = 17; i < 256; i++) {

        bank(i);
        for (int j = 0; j < 4096; j++) {
            if (vm[j] != (j & 255)) {
                err++;
            }
        }

        D.locate(0, 3);
        D.print("ERRORS ");
        D.prnint(err);
    }

    for(;;);
}
