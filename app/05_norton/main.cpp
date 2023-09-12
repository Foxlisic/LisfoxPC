#include <avrio.h>
#include <display3.h>

Display3 D;


// id: 0-left, 1-right; active = 0/1
void panel(char id, char active, char letter) {

    D.color(0x1B);

    int i;
    int x1 = id ? 40 : 0;
    int x2 = id ? 79 : 39;

    D.block(x1, 0, x2, 22, 0x1B);
    D.frame(x1, 0, x2, 22, 1);

    // Наименования панелей
    D.color(active ? 0x30 : 0x1B);
    D.locate(x1 + 17, 0);
    D.print(" X:\\ ");
    D.put(x1 + 18, 0, letter);
    D.locate(x1 + 5, 1);
    D.color(0x1E);
    D.print("Name        Size     Date    Time");

    // Вертикальные полосы
    D.color(0x1B);
    for (i = 1; i < 20; i++) {
        D.put(x1 + 13, i, 0xB3);
        D.put(x1 + 23, i, 0xB3);
        D.put(x1 + 32, i, 0xB3);
    }
    for (i = 1; i < 39; i++) D.put(x1 + i, 20, 0xC4);

    D.put(x1 + 13, 0, 0xD1); D.put(x1 + 13, 20, 0xC1);
    D.put(x1 + 23, 0, 0xD1); D.put(x1 + 23, 20, 0xC1);
    D.put(x1 + 32, 0, 0xD1); D.put(x1 + 32, 20, 0xC1);
    D.put(x1,     20, 0xC7); D.put(x1 + 39, 20, 0xB6);
}

// Форматированная печать
void print_format(const char* s) {

    int i = 0;
    while (s[i]) {

        switch (s[i]) {
            case 1: D.color(0x07); break;
            case 2: D.color(0x30); break;
            default: D.prn(s[i]); break;
        }
        i++;
    }
}

// Перерисовать полностью экран
void redraw() {

    D.cls(0x07);

    // Две панели
    panel(0, 1, 'C');
    // panel(1, 0, 'A');

    // Строки с подписями
    D.locate(0, 24);
    print_format("\x01""1""\x02""Help  ""\x01"" 2""\x02""Menu  ""\x01"" 3""\x02""View  ""\x01"" 4""\x02""Edit  ""\x01"" 5""\x02""Copy  ""\x01"" 6""\x02""RenMov""\x01"" 7""\x02""MkDir ""\x01"" 8""\x02""Delete""\x01"" 9""\x02""PullDn""\x01"" 10""\x02""Quit ");

    // Приглашение командной строки
    D.locate(0, 23);
    D.color(0x07);
    D.print("C:>");
}

int main() {

    redraw();
    for(;;);
}
