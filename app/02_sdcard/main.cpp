#include <avrio.h>
#include <display3.h>
#include <sd.h>

Display3 D;
SD       sd;
byte     sector[512];

int main() {

    D.cls();

    sd.read (0, sector);

    for(;;);
}
