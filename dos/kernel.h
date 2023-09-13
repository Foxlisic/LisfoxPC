#include <sd.h>
#include <kb.h>
#include <display3.h>

#define printf(x) ds.print(x)

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
extern const char LOGO[] PROGMEM;
const char LOGO[] = "2023 LisfoxPC Enterprise Incorporated Ltd | Copyleft LICENSE Warranty |  [Ready]";
// -----------------------------------------------------------------------------

class Kernel {
protected:

    byte bash[81];
    byte bash_x, bash_y;

public:

    // Перезапуск
    void reset() {

        ei(0);

        ds.cls(0x07);

        // Выдать строку приглашения
        ds.color(0x70); ds.print(LOGO, 1); ds.color(0x07);
        // ---

        bash_x = 0;
        bash_y = 1;

        for (int i = 0; i < 81; i++) bash[i] = 0;

        ei(2);
    }

    // Ввод текста с отображением печати
    void bashin() {

        byte ch; int i;

        do {

            // Ожидать приема символа
            ch = kb.getch();

            // Добавит символ
            if (ch >= 32 && bash_x < 79) {

                for (i = 79; i > bash_x; i--) bash[i] = bash[i-1];
                bash[bash_x++] = ch;
            }
            // Удалить символ
            else if (ch == 8 && bash_x > 0) {

                bash[--bash_x] = 0;
                for (i = bash_x; i < 80; i++) bash[i] = bash[i+1];
            }
            // Влево, Вправо
            else if (ch == VK_LF && bash_x > 0) bash_x--;
            else if (ch == VK_RT && bash_x < 79 && bash[bash_x]) bash_x++;
            // Home, End
            else if (ch == VK_HOME) bash_x = 0;
            else if (ch == VK_END) { bash_x = 78; while (i > 0 && bash[bash_x] == 0) bash_x--; bash_x++; }
            // Завершение строки
            else if (ch == VK_ENT) { bash_x = 0; }

            // Вывести все символы
            for (i = 0; i < 80; i++) ds.put(i, bash_y, bash[i]);

            // Перевод на следующую строку
            if (ch == VK_ENT) { bash_y++; }

            ds.locate(bash_x, bash_y);
        }
        while (ch != VK_ENT);
    }
};
