#include <avrio.h>
#include <displayzx.h>

DisplayZX zx;

int main() {

    zx.cls(0x07);

    //zx.attrb(1,1,18,1,1*8+7+0x40);
    zx.attrb(1,1,20,1,1*8+7);
    zx.attrb(1,2,20,2,0x38);
    zx.attrb(1,3,20,10,0x38 + 0x40);
    zx.loc(8,8); zx.print4("# Googlenote");
    zx.loc(8,16); zx.print4(" File Edit About");
    zx.loc(10,26); zx.print("Ничего, если я кот?");

    for(;;);
}
