
// Объявить о наличии KbATnT
extern const byte KbATnT[] PROGMEM;

/*
 * 1  ^  TOP
 * 2  -> RIGHT
 * 3  v  DOWN
 * 4  <- LEFT
 * 5  Home
 * 6  End
 * 7  Caps Lock
 * 8  BkSpc
 * 9  Tab
 * 10 Enter
 * ----------------------------------
 * 11-F1  | 14-F4  | 17-F7  | 20-F10
 * 12-F2  | 15-F5  | 18-F8  | 21-F11
 * 13-F3  | 16-F6  | 19-F9  | 22-F12
 * ----------------------------------
 * 23 PgUp
 * 24 PgDn
 * 25 Del
 * 26 Ins
 * 27 Esc
 * 28 Win
 * 29 Scroll
 * 30 NumLock
 * 31 GUI
 * */

const byte KbATnT[] =
{
// 0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F
  0x00,0x13,' ',0x0F,0x0D,0x0B,0x0C,0x16, ' ',0x14,0x12,0x10,0x0E,0x09, '`', ' ', // 0
  ' ', ' ', ' ', ' ', ' ', 'q', '1', ' ', ' ', ' ', 'z', 's', 'a', 'w', '2', ' ', // 1
  ' ', 'c', 'x', 'd', 'e', '4', '3', ' ', ' ',0x20, 'v', 'f', 't', 'r', '5', ' ', // 2
  ' ', 'n', 'b', 'h', 'g', 'y', '6', ' ', ' ', ' ', 'm', 'j', 'u', '7', '8', ' ', // 3
  ' ', ',', 'k', 'i', 'o', '0', '9', ' ', ' ', '.', '/', 'l', ';', 'p', '-', ' ', // 4
  ' ', ' ', '\'',' ', '[', '=', ' ', ' ',0x07, ' ',0x0A, ']', ' ', '\\',' ', ' ', // 5
  ' ', ' ', ' ', ' ', ' ', ' ',0x08, ' ', ' ', '1', ' ', '4', '7', ' ', ' ', ' ', // 6
  '0', '.', '2', '5', '6', '8',0x1B,0x1E,0x15, '+', '3', '-', '*', '9',0x1D, ' ', // 7
  // ---------------------------------------------------------------------------
    0,   0,   0,0x11,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0, // 8
  ' ', ' ', ' ', ' ', ' ', 'Q', '!', ' ', ' ', ' ', 'Z', 'S', 'A', 'W', '@', ' ', // 9
  ' ', 'C', 'X', 'D', 'E', '$', '#', ' ', ' ', ' ', 'V', 'F', 'T', 'R', '%', ' ', // A
  ' ', 'N', 'B', 'H', 'G', 'Y', '^', ' ', ' ', ' ', 'M', 'J', 'U', '&', '*', ' ', // B
  ' ', ',', 'K', 'I', 'O', ')', '(', ' ', ' ', '.', '?', 'L', ':', 'P', '_', ' ', // C
  ' ', ' ', '"', ' ', '{', '+', ' ', ' ', ' ', ' ', ' ', '}', ' ', '|', ' ', ' ', // D
  ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', '!', ' ', '$', '&', ' ', ' ', ' ', // E
  ')', '>', '@', '%', '^', '*', ' ', ' ', ' ', '+', '#', '_', '*', '(', ' ', ' ', // F
};

class Keyboard {
protected:

    volatile byte release, st, ed, spec, shift, alt, ctrl;
    volatile byte queue[16];

public:

    Keyboard() { release = st = ed = spec = shift = alt = ctrl = 0; }

    // Разобрать клавишу AT&T -> очередь FIFO
    void recv() {

        byte in = inp(KEYB);
        byte ot = 0;

        if      (in == 0xE0) spec    = 1; // Специальная клавиша
        else if (in == 0xF0) release = 1; // Признак отпущенной клавиши
        else {

            // Нажатие на...
            if (spec == 0 && (in == 0x12 || in == 0x59)) { // SHIFT
                shift = release ? 0 : 1;
            } else if (in == 0x11) { // ALT
                alt = release ? 0 : 1;
            } else if (in == 0x14) { // CTRL
                ctrl = release ? 0 : 1;
            } else if (release == 0) { // Нажатая клавиша

                ot = 0;
                if (spec) {

                    if      (in == 0x1F || in == 0x27) ot = 31; // GUI
                    else if (in == 0x2F) ot = 28; // Win
                    else if (in == 0x70) ot = 26; // Ins
                    else if (in == 0x6C) ot = 5;  // Home
                    else if (in == 0x69) ot = 6;  // End
                    else if (in == 0x7D) ot = 23; // PgUp
                    else if (in == 0x7A) ot = 24; // PgDn
                    else if (in == 0x71) ot = 25; // Del
                    else if (in == 0x75) ot = 1;  // Up
                    else if (in == 0x74) ot = 2;  // Rt
                    else if (in == 0x72) ot = 3;  // Dn
                    else if (in == 0x6B) ot = 4;  // Lf

                } else {
                    ot = pgm_read_byte(& KbATnT[in | (shift ? 0x80 : 0)]);
                }

                if (ot) {
                    queue[ed] = ot;
                    ed = (ed + 1) & 15;
                }
            }

            spec = release = 0;
        }
    }

    // Неблокирующий
    byte get() {

        // Если st <> ed, то есть символ в очереди
        if (st != ed) {

            byte ch = queue[st];
            st = (st + 1) & 15;
            return ch;
        }

        return 0;
    }

    // Блокирующий
    byte getch() {

        byte x = 0;
        while (0 == (x = get()));
        return x;
    }
};
