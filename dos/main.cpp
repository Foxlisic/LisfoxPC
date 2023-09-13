#include <avrio.h>

#include "filesys.h"
#include "kernel.h"

Kernel core;

int main() {

    core.reset();
    core.bashin();

    for(;;);
}
