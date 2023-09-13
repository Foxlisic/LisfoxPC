#include <sd.h>
#include <kb.h>
#include <display3.h>

// Объявление модулей
Keyboard    kb;
Display3    ds;
SD          sd;

// Пространство для временных переменных
byte        sector[512];

// -----------------------------------------------------------------------------

// 1 VSYNC
ISR(INT0_vect) { eoi; }

// 2 KEYBOARD
ISR(INT1_vect) { kb.recv(); eoi; }

// -----------------------------------------------------------------------------

class Kernel {
protected:

    byte bash[81];
    byte bash_x;

public:

    // Перезапуск
    void reset() {

        ei(0);

        ds.cls(0x07);

        // Выдать строку приглашения
        ds.color(0x70);
        ds.print("2023 LisfoxPC Enterprise Incorporated Ltd | Copyleft LICENSE Warranty |  [Ready]");
        ds.color(0x07);
        // ---

        bash_x = 0;

        ei(2);
    }

    // Ввод текста с отображением печати
    void input() {
    }
};
