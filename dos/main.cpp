#include <avrio.h>

#include "filesys.h"
#include "kernel.h"

Kernel core;

int main() {

    core.reset();

    // core.input();

    for (;;) { ds.prn(kb.getch()); }

    // ei(3);
    for(;;);
}
