#include <avrio.h>
#include <display3.h>
#include <kb.h>

Display3 D;
Keyboard KB;

ISR(INT1_vect) { KB.recv(); eoi; }

int main() {

    D.cls();
    ei(2);

    for(;;) {

        byte x = KB.get();
        if (x) D.prn(x);

    }
}
