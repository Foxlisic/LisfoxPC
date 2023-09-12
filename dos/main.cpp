#include <avrio.h>

ISR(INT0_vect) { eoi; } // 1 VSYNC
ISR(INT1_vect) { eoi; } // 2 KEYBOARD :: Keyboard KB; KB.recv();

int main() {

    ei(3);
    for(;;);
}
